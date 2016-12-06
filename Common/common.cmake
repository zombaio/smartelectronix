cmake_minimum_required(VERSION 3.5)

#*******************************************************************************
# Pre-building function, set variables which need to be set before project()
# is called...
#*******************************************************************************
function(pre_build)
  if (APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.9" PARENT_SCOPE)
    set(CMAKE_OSX_ARCHITECTURES "i386" "x86_64" PARENT_SCOPE)
  endif()
endfunction(pre_build)

#*******************************************************************************
# Adds VST SDK to target
#
# @param VST_TARGET The cmake target to which the VST SDK will be added.
#*******************************************************************************
function(add_vstsdk VST_TARGET)
  set(STEINBERG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../Steinberg)

  set(VST_SOURCE
    ${STEINBERG_DIR}/public.sdk/source/vst2.x/audioeffect.cpp
    ${STEINBERG_DIR}/public.sdk/source/vst2.x/audioeffectx.cpp
    ${STEINBERG_DIR}/public.sdk/source/vst2.x/vstplugmain.cpp
    ${STEINBERG_DIR}/public.sdk/source/vst2.x/aeffeditor.h
    ${STEINBERG_DIR}/public.sdk/source/vst2.x/audioeffect.h
    ${STEINBERG_DIR}/public.sdk/source/vst2.x/audioeffectx.h
  )

  set(VST_INTERFACE
    ${STEINBERG_DIR}/pluginterfaces/vst2.x/aeffect.h
    ${STEINBERG_DIR}/pluginterfaces/vst2.x/aeffectx.h
    ${STEINBERG_DIR}/pluginterfaces/vst2.x/vstfxstore.h
  )

  source_group("vst2.x" FILES ${VST_SOURCE})
  source_group("Interfaces" FILES ${VST_INTERFACE})

  target_sources(${VST_TARGET} PUBLIC ${VST_SOURCE} ${VST_INTERFACE})
  target_include_directories(${VST_TARGET} PUBLIC ${STEINBERG_DIR})

endfunction(add_vstsdk)

#*******************************************************************************
# Create windows .rc resource file
#
# @param PROJECT_IMAGES    List of image paths for the project.
#*******************************************************************************
function(create_resource_file PROJECT_IMAGES)
  set(RESOURCES_LIST)

  foreach (IMAGE_PATH ${PROJECT_IMAGES})
    get_filename_component(IMAGE_FILENAME ${IMAGE_PATH} NAME)
    list(APPEND RESOURCES_LIST "${IMAGE_FILENAME}\tPNG\t\"${IMAGE_PATH}\"\n")
  endforeach(IMAGE_PATH ${PROJECT_IMAGES})

  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/resource.rc ${RESOURCES_LIST})
endfunction(create_resource_file)

#*******************************************************************************
# Adds VSTGUI to target
#
# @param VST_TARGET        The cmake target to which the VSTGUI libray will be
#                          added.
# @param VST_TARGET_IMAGES The images used in the cmake targets GUI
#*******************************************************************************
function(add_vstgui VST_TARGET VST_TARGET_IMAGES)

  set(VSTGUI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../vstgui/vstgui)

  set(VSTGUI_SOURCE
    ${VSTGUI_DIR}/plugin-bindings/aeffguieditor.cpp
    ${VSTGUI_DIR}/plugin-bindings/aeffguieditor.h
  )

  if(WIN32)

    list(APPEND VSTGUI_SOURCE ${VSTGUI_DIR}/vstgui_win32.cpp)

    create_resource_file("${VST_TARGET_IMAGES}")
    target_sources(${VST_TARGET} PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/resource.rc)

  elseif(APPLE)
    list(APPEND VSTGUI_SOURCE ${VSTGUI_DIR}/vstgui_mac.mm)

    # ignore deprecated warnings generated by VST GUI
    set_source_files_properties(
      ${VSTGUI_SOURCE} PROPERTIES COMPILE_FLAGS
      "-Wno-deprecated-declarations"
    )

    find_library(CARBON Carbon)
    find_library(COCOA Cocoa)
    find_library(OPENGL OpenGL)
    find_library(ACCELERATE Accelerate)
    find_library(QUARTZ QuartzCore)
    target_link_libraries(
      ${VST_TARGET} ${CARBON} ${COCOA} ${OPENGL} ${ACCELERATE} ${QUARTZ}
    )
    set_source_files_properties(${VST_TARGET_IMAGES} PROPERTIES
      MACOSX_PACKAGE_LOCATION Resources
    )

  endif(WIN32)

  source_group("vstgui" FILES ${VSTGUI_SOURCE})

  target_sources(${VST_TARGET} PUBLIC ${VSTGUI_SOURCE} ${VST_TARGET_IMAGES})
  target_include_directories(${VST_TARGET} PUBLIC ${VSTGUI_DIR})

endfunction(add_vstgui)

#*******************************************************************************
# Generates a VST cmake target
#
# @param VST_TARGET        The name of the target to generate
# @param VST_TARGET_IMAGES The images used in the targets GUI. If the target
#                          doesn't have a GUI then pass FALSE to disable.
#*******************************************************************************
function(build_vst VST_TARGET VST_TARGET_SOURCES VST_TARGET_IMAGES)

  set(COMMON_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../Common)

  add_library(${VST_TARGET} MODULE ${VST_TARGET_SOURCES})

  add_vstsdk("${VST_TARGET}")
  if (VST_TARGET_IMAGES)
    add_vstgui("${VST_TARGET}" "${VST_TARGET_IMAGES}")
  endif(VST_TARGET_IMAGES)

  if(WIN32)

    target_sources(${VST_TARGET} PUBLIC ${COMMON_DIR}/exports.def)
    add_definitions(-D_CRT_SECURE_NO_DEPRECATE=1)

    if(${PLUGIN_ARCH} STREQUAL "x86")
      add_test(
        NAME MrsWatson-${VST_TARGET}-32
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
        COMMAND bin/win/mrswatson -p ${VST_TARGET} -i media/input.wav -o out.wav
      )
    elseif(${PLUGIN_ARCH} STREQUAL "x64")
      add_test(
        NAME MrsWatson-${VST_TARGET}-64
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
        COMMAND bin/win/mrswatson64 -p ${VST_TARGET} -i media/input.wav -o out.wav
      )
    endif()

  elseif(APPLE)
    set(PKG_INFO ${COMMON_DIR}/PkgInfo)
    set_source_files_properties(${COMMON_DIR}/PkgInfo PROPERTIES
      MACOSX_PACKAGE_LOCATION .
    )
    target_sources(${VST_TARGET} PUBLIC ${PKG_INFO} )
    set_target_properties(${VST_TARGET} PROPERTIES
      BUNDLE true
      BUNDLE_EXTENSION vst
      MACOSX_BUNDLE_INFO_PLIST ${COMMON_DIR}/Info.plist.in
    )
    set_property(TARGET ${VST_TARGET} PROPERTY CXX_STANDARD 11)

    install(TARGETS ${VST_TARGET} DESTINATION ~/Library/Audio/Plug-Ins/VST)

    add_test(
      NAME MrsWatson-${VST_TARGET}-64
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
      COMMAND bin/osx/mrswatson64 -p ${VST_TARGET}/${VST_TARGET}.vst -i media/input.wav -o out.wav
    )

    add_test(
      NAME MrsWatson-${VST_TARGET}-32
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
      COMMAND bin/osx/mrswatson -p ${VST_TARGET}/${VST_TARGET}.vst -i media/input.wav -o out.wav
    )

  endif(WIN32)

endfunction(build_vst)

#*******************************************************************************
# Convenience function for generating VST cmake targets with guis
#
# @param VST_TARGET         The name of the target to generate
# @param VST_TARGET_SOURCES The source files for the target
# @param VST_TARGET_IMAGES  The images used in the targets GUI
#*******************************************************************************
function(build_vst_gui VST_TARGET VST_TARGET_SOURCES VST_TARGET_IMAGES)

  build_vst("${VST_TARGET}" "${VST_TARGET_SOURCES}" "${VST_TARGET_IMAGES}")

endfunction(build_vst_gui)

#*******************************************************************************
# Convenience function for generating VST cmake targets without guis
#
# @param VST_TARGET         The name of the target to generate
# @param VST_TARGET_SOURCES The source files for the target
#*******************************************************************************
function(build_vst_nogui VST_TARGET VST_TARGET_SOURCES)

  build_vst("${VST_TARGET}" "${VST_TARGET_SOURCES}" FALSE)

endfunction(build_vst_nogui)
