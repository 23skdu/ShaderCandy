cmake_minimum_required(VERSION 3.20)
project(ShaderCandy VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization Flags
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

if(APPLE)
    add_compile_options(-O3 -ffast-math -fstrict-aliasing)
else()
    add_compile_options(-O3 -ffast-math)
endif()
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Options
option(BUILD_METAL "Build Metal backend (macOS only)" ON)
option(BUILD_OPENGL "Build OpenGL backend" ON)
option(BUILD_TESTS "Build tests" ON)
option(BUILD_SCREENSAVER_MACOS "Build macOS screensaver" ON)
option(BUILD_SCREENSAVER_LINUX "Build Linux X11 screensaver" ON)

# Detect platform
if(APPLE)
    set(MACOS TRUE)
elseif(UNIX)
    set(LINUX TRUE)
endif()

# Find packages
find_package(Threads REQUIRED)

# Core library - shared code
set(CORE_SOURCES
    src/core/ShaderManager.cpp
    src/core/UniformBuffer.cpp
    src/core/PerformanceMonitor.cpp
    src/config/ConfigurationManager.cpp
    src/config/PresetManager.cpp
)

# Linux Audio support
if(LINUX)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(ALSALIB REQUIRED alsa)
    pkg_check_modules(FFTW3 REQUIRED fftw3)
    
    set(LINUX_AUDIO_SOURCES
        src/audio/AudioInput_Linux.cpp
    )
    
    add_library(shadercandy_audio_linux STATIC ${LINUX_AUDIO_SOURCES})
    target_include_directories(shadercandy_audio_linux PUBLIC 
        src/audio
        ${ALSALIB_INCLUDE_DIRS}
        ${FFTW3_INCLUDE_DIRS}
    )
    target_link_libraries(shadercandy_audio_linux PUBLIC
        shadercandy_core
        ${ALSALIB_LIBRARIES}
        ${FFTW3_LIBRARIES}
    )
    target_compile_options(shadercandy_audio_linux PUBLIC
        ${ALSALIB_CFLAGS_OTHER}
        ${FFTW3_CFLAGS_OTHER}
    )
endif()

set(CORE_HEADERS
    src/core/ShaderManager.h
    src/core/UniformBuffer.h
    src/core/PerformanceMonitor.h
    src/core/MathUtils.h
    src/config/ConfigurationManager.h
    src/config/PresetManager.h
)

add_library(shadercandy_core STATIC ${CORE_SOURCES} ${CORE_HEADERS})
target_include_directories(shadercandy_core PUBLIC src/core)
target_link_libraries(shadercandy_core PUBLIC Threads::Threads)

# SIMD optimizations
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm|ARM|aarch64|AARCH64")
    target_compile_definitions(shadercandy_core PUBLIC USE_NEON)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_options(shadercandy_core PUBLIC -march=armv8-a+fp+simd)
    endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86|X86|amd64|AMD64")
    target_compile_definitions(shadercandy_core PUBLIC USE_AVX2)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_options(shadercandy_core PUBLIC -mavx2 -mfma)
    elseif(MSVC)
        target_compile_options(shadercandy_core PUBLIC /arch:AVX2)
    endif()
endif()

# CoreML and UniformTypeIdentifiers for Phase 5 features
if(MACOS)
    find_library(COREML_FRAMEWORK CoreML REQUIRED)
    find_library(UNIFORMTYPEIDENTIFIERS_FRAMEWORK UniformTypeIdentifiers REQUIRED)
endif()

# macOS Metal Backend
if(MACOS AND BUILD_METAL)
    enable_language(OBJCXX)
    
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
    find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)
    find_library(COREMEDIA_FRAMEWORK CoreMedia REQUIRED)
    
    # Metal sources - unified renderer and supporting classes
    set(METAL_SOURCES
        src/metal/MetalRenderer.mm
        src/metal/ShaderCompiler.mm
        src/metal/MetalPipelineCache.mm
        src/metal/MetalResourcePool.mm
        src/metal/MetalHeapManager.mm
        src/metal/MTLPerformanceReporter.mm
        src/metal/MetalSharedState.mm
        src/metal/HDRPipeline.mm
        src/metal/DynamicRangeOptimizer.mm
        src/metal/HDRMetadataGenerator.mm
        src/neural/NeuralStyleEngine.mm
        src/neural/StyleTransferModel.mm
        src/neural/StyleLibrary.mm
    )

    set(AUDIO_SOURCES
        src/audio/AudioInput.mm
        src/audio/SoundscapeGenerator.mm
        src/audio/AcousticSimulator.mm
        src/audio/RayAudioEngine.mm
        src/audio/SpatialSoundscapeGenerator.mm
    )
    
    add_library(shadercandy_metal STATIC ${METAL_SOURCES})
    target_include_directories(shadercandy_metal PUBLIC src/metal src/platform/macos)
    target_compile_options(shadercandy_metal PUBLIC -fobjc-arc)
    target_link_libraries(shadercandy_metal PUBLIC
        shadercandy_core
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${QUARTZCORE_FRAMEWORK}
        ${COREML_FRAMEWORK}
        ${UNIFORMTYPEIDENTIFIERS_FRAMEWORK}
    )

    add_library(shadercandy_audio STATIC ${AUDIO_SOURCES})
    target_include_directories(shadercandy_audio PUBLIC src/audio)
    target_compile_options(shadercandy_audio PUBLIC -fobjc-arc)
    target_link_libraries(shadercandy_audio PUBLIC
        shadercandy_core
        ${AVFOUNDATION_FRAMEWORK}
        ${ACCELERATE_FRAMEWORK}
        ${COREMEDIA_FRAMEWORK}
    )
    
    # Check for Metal compiler
    find_program(XCRUN_EXECUTABLE xcrun)
    if(XCRUN_EXECUTABLE)
        execute_process(COMMAND ${XCRUN_EXECUTABLE} -f metal OUTPUT_VARIABLE METAL_COMPILER OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    endif()

    # Compile all Metal shaders to individual metallib files
    if(METAL_COMPILER AND XCRUN_EXECUTABLE)
        file(GLOB METAL_SOURCE_SHADERS "shaders/**/*.metal")
        
        foreach(shader_source ${METAL_SOURCE_SHADERS})
            get_filename_component(shader_name ${shader_source} NAME_WE)
            get_filename_component(shader_dir ${shader_source} DIRECTORY)
            
            # Create output directory structure
            file(RELATIVE_PATH relative_dir ${CMAKE_SOURCE_DIR}/shaders ${shader_dir})
            set(output_dir ${CMAKE_BINARY_DIR}/shaders/${relative_dir})
            file(MAKE_DIRECTORY ${output_dir})
            
            # Compile to .air (intermediate)
            set(air_file ${output_dir}/${shader_name}.air)
            
            # Compile to .metallib
            set(metallib_file ${output_dir}/${shader_name}.metallib)
            
            add_custom_command(
                OUTPUT ${metallib_file}
                COMMAND ${XCRUN_EXECUTABLE} -sdk macosx metal -c ${shader_source} -o ${air_file}
                COMMAND ${XCRUN_EXECUTABLE} -sdk macosx metallib ${air_file} -o ${metallib_file}
                DEPENDS ${shader_source}
                COMMENT "Compiling Metal shader: ${shader_name}"
                VERBATIM
            )
            
            list(APPEND METALLIB_FILES ${metallib_file})
        endforeach()
        
        # Custom target to compile all shaders
        add_custom_target(metal_shaders DEPENDS ${METALLIB_FILES})
        
        message(STATUS "Metal shader compilation: Enabled (${METAL_SOURCE_SHADERS})")
    else()
        message(STATUS "Metal compiler not found. Shaders will be compiled at runtime.")
        add_custom_target(metal_shaders)
    endif()
endif()

# OpenGL Backend (optional - may not be implemented yet)
if(BUILD_OPENGL)
    # Check if GL source files exist
    if(EXISTS "${CMAKE_SOURCE_DIR}/src/gl/GLRenderer.cpp")
        set(OPENGL_SOURCES
            src/gl/GLRenderer.cpp
            src/gl/GLShaderCompiler.cpp
        )
        
        add_library(shadercandy_gl STATIC ${OPENGL_SOURCES})
        target_include_directories(shadercandy_gl PUBLIC src/gl)
        target_link_libraries(shadercandy_gl PUBLIC
            shadercandy_core
            OpenGL::GL
        )
        
        if(LINUX)
            find_package(X11 REQUIRED)
            find_library(XSS_LIB Xss REQUIRED)
            target_link_libraries(shadercandy_gl PUBLIC
                ${X11_LIBRARIES}
                ${X11_Xmu_LIB}
                ${XSS_LIB}
            )
        endif()
    else()
        message(STATUS "OpenGL backend sources not found. Set BUILD_OPENGL=OFF to disable.")
        set(BUILD_OPENGL OFF CACHE BOOL "Build OpenGL backend" FORCE)
    endif()
endif()

# macOS Screensaver
if(MACOS AND BUILD_SCREENSAVER_MACOS)
    # Use the new adapter-based architecture
    set(SCREENSAVER_SOURCES
        src/platform/macos/MacOSMetalViewAdapter.mm
    )
    
    find_library(SCREENSAVER_FRAMEWORK ScreenSaver REQUIRED)
    
    # Bundle resources - shaders and textures
    file(GLOB BUNDLE_RESOURCES
        shaders/**/*.metal
        shaders/**/*.glsl
        shaders/**/*.frag
        textures/*.png
        src/core/ShaderInterop.h
    )
    
    # Add compiled metallibs if they exist/will be built
    if(TARGET metal_shaders)
        file(GLOB METALLIB_RESOURCES "${CMAKE_BINARY_DIR}/shaders/**/*.metallib")
        list(APPEND BUNDLE_RESOURCES ${METALLIB_RESOURCES})
    endif()
    
    add_library(ShaderCandy MODULE
        ${SCREENSAVER_SOURCES}
        ${BUNDLE_RESOURCES}
    )
    
    # Set resource location for shaders and textures
    foreach(res ${BUNDLE_RESOURCES})
        get_filename_component(res_name ${res} NAME)
        if(res MATCHES ".*\\.metallib")
             set_source_files_properties(${res} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/shaders)
        elseif(res MATCHES ".*\\.png")
             set_source_files_properties(${res} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/textures)
        else()
             set_source_files_properties(${res} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/shaders)
        endif()
    endforeach()
    
    set_target_properties(ShaderCandy PROPERTIES
        BUNDLE TRUE
        BUNDLE_EXTENSION saver
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/src/platform/macos/Info.plist.in
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.shadercandy.screensaver"
        MACOSX_BUNDLE_BUNDLE_NAME "ShaderCandy"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
    )
    
    find_library(COCOA_FRAMEWORK Cocoa REQUIRED)

    target_include_directories(ShaderCandy PRIVATE
        src/core
        src/platform/macos
        src/metal
        ${CMAKE_SOURCE_DIR}
    )

    target_link_libraries(ShaderCandy PRIVATE
        shadercandy_core
        shadercandy_metal
        shadercandy_audio
        ${SCREENSAVER_FRAMEWORK}
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${QUARTZCORE_FRAMEWORK}
        ${COCOA_FRAMEWORK}
        ${COREMEDIA_FRAMEWORK}
    )
    
    if(TARGET metal_shaders)
        add_dependencies(ShaderCandy metal_shaders)
    endif()
 endif()

 # macOS Standalone Player App
 option(BUILD_STANDALONE_APP "Build macOS standalone player app" ON)
 if(MACOS AND BUILD_STANDALONE_APP)
     enable_language(OBJCXX)
     
       set(STANDALONE_APP_SOURCES
           src/platform/macos/main.mm
           src/platform/macos/StandaloneAppDelegate.mm
           src/platform/macos/StandaloneAppWindowController.mm
           src/platform/macos/screenshot_utility.mm
           src/platform/macos/PreferencesWindowController.mm
           src/platform/macos/ShadersListViewController.mm
           src/platform/macos/PresetViewController.mm
           src/platform/macos/PresetObject.mm
           src/platform/macos/PresetImportExportSheet.mm
           src/neural/StyleLibraryViewController.mm
       )
     
     # Find Cocoa framework
     find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
     
      # Bundle resources - shaders and textures (must be before add_executable)
      file(GLOB_RECURSE STANDALONE_RESOURCES
          "shaders/*.metal"
          "shaders/*.glsl"
          "shaders/*.frag"
          "textures/*.png"
          "src/core/ShaderInterop.h"
      )
     
     foreach(res ${STANDALONE_RESOURCES})
         get_filename_component(res_name ${res} NAME)
         if(res MATCHES ".*\\.metal" OR res MATCHES ".*\\.glsl" OR res MATCHES ".*\\.frag" OR res MATCHES ".*\\.h")
             set_source_files_properties(${res} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/shaders)
         elseif(res MATCHES ".*\\.png")
             set_source_files_properties(${res} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/textures)
         endif()
     endforeach()
     
     add_executable(ShaderCandyPlayer ${STANDALONE_APP_SOURCES} ${STANDALONE_RESOURCES})
     
      # Set bundle properties - use player-specific Info.plist
     set_target_properties(ShaderCandyPlayer PROPERTIES
         MACOSX_BUNDLE TRUE
         MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/src/platform/macos/Info_Player.plist.in
         MACOSX_BUNDLE_GUI_IDENTIFIER "com.shadercandy.player"
         MACOSX_BUNDLE_BUNDLE_NAME "ShaderCandy Player"
         MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
         MACOSX_BUNDLE_BUNDLE_VERSION "1"
     )
      
      target_include_directories(ShaderCandyPlayer PRIVATE
          src/core
          src/platform/macos
          src/metal
          src/audio
          src/config
          src/neural
          ${CMAKE_SOURCE_DIR}
      )
     
      find_library(COREML_FRAMEWORK CoreML REQUIRED)
      find_library(UNIFORMTYPEIDENTIFIERS_FRAMEWORK UniformTypeIdentifiers REQUIRED)

       target_link_libraries(ShaderCandyPlayer PRIVATE
           shadercandy_core
           shadercandy_metal
           shadercandy_audio
           ${COCOA_FRAMEWORK}
           ${METAL_FRAMEWORK}
           ${METALKIT_FRAMEWORK}
           ${QUARTZCORE_FRAMEWORK}
           ${AVFOUNDATION_FRAMEWORK}
           ${ACCELERATE_FRAMEWORK}
           ${COREMEDIA_FRAMEWORK}
           ${COREML_FRAMEWORK}
           ${UNIFORMTYPEIDENTIFIERS_FRAMEWORK}
           "-framework Foundation"
          "-framework AppKit"
      )
     
     if(TARGET metal_shaders)
         add_dependencies(ShaderCandyPlayer metal_shaders)
     endif()
     
     # Install
     install(TARGETS ShaderCandyPlayer
         BUNDLE DESTINATION Applications
     )
 endif()

 # Linux X11 Screensaver
if(LINUX AND BUILD_SCREENSAVER_LINUX)
    # Check if Linux source files exist
    if(EXISTS "${CMAKE_SOURCE_DIR}/src/platform/linux/screensaver.cpp")
        set(LINUX_SCREENSAVER_SOURCES
            src/platform/linux/screensaver.cpp
        )
        
        # Find X11 libraries (Xmu and Xss are optional)
        find_package(X11 REQUIRED)
        find_library(XSS_LIB Xss)
        find_library(XMU_LIB Xmu)
        
        add_executable(shadercandy-screensaver ${LINUX_SCREENSAVER_SOURCES})
        target_include_directories(shadercandy-screensaver PRIVATE
            src/core
            src/audio
            ${ALSALIB_INCLUDE_DIRS}
            ${FFTW3_INCLUDE_DIRS}
        )
        target_link_libraries(shadercandy-screensaver PRIVATE
            shadercandy_core
            shadercandy_audio_linux
            ${X11_LIBRARIES}
            GL
            ${ALSALIB_LIBRARIES}
            ${FFTW3_LIBRARIES}
            pthread
        )
        
        if(XSS_LIB)
            target_link_libraries(shadercandy-screensaver PRIVATE ${XSS_LIB})
        endif()
        
        if(XMU_LIB)
            target_link_libraries(shadercandy-screensaver PRIVATE ${XMU_LIB})
        endif()
        
        # Install
        install(TARGETS shadercandy-screensaver
            RUNTIME DESTINATION bin
        )
        
        # Linux Standalone Player
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(GLFW REQUIRED glfw3)
        
        add_executable(shadercandy-player src/platform/linux/standalone_player.cpp)
        target_include_directories(shadercandy-player PRIVATE
            src/core
            src/audio
            ${GLFW_INCLUDE_DIRS}
            ${ALSALIB_INCLUDE_DIRS}
            ${FFTW3_INCLUDE_DIRS}
        )
        target_link_libraries(shadercandy-player PRIVATE
            shadercandy_core
            shadercandy_audio_linux
            ${GLFW_LIBRARIES}
            ${GLFW_STATIC_LIBRARIES}
            GL
            ${ALSALIB_LIBRARIES}
            ${FFTW3_LIBRARIES}
            pthread
        )
        target_compile_options(shadercandy-player PRIVATE
            ${GLFW_CFLAGS_OTHER}
            ${ALSALIB_CFLAGS_OTHER}
            ${FFTW3_CFLAGS_OTHER}
        )
        
        install(TARGETS shadercandy-player
            RUNTIME DESTINATION bin
        )
        
        # Linux Wallpaper Mode
        add_executable(shadercandy-wallpaper src/platform/linux/wallpaper.cpp)
        target_include_directories(shadercandy-wallpaper PRIVATE
            src/core
            src/audio
            ${X11_INCLUDE_DIR}
            ${ALSALIB_INCLUDE_DIRS}
            ${FFTW3_INCLUDE_DIRS}
        )
        target_link_libraries(shadercandy-wallpaper PRIVATE
            shadercandy_core
            shadercandy_audio_linux
            ${X11_LIBRARIES}
            ${X11_Xcomposite_LIB}
            ${X11_Xrender_LIB}
            GL
            ${ALSALIB_LIBRARIES}
            ${FFTW3_LIBRARIES}
            pthread
        )
        
        install(TARGETS shadercandy-wallpaper
            RUNTIME DESTINATION bin
        )
        
        # Install all GLSL shaders
        file(GLOB GLSL_SHADERS 
            ${CMAKE_SOURCE_DIR}/shaders/*.frag
            ${CMAKE_SOURCE_DIR}/shaders/effects/*.frag
        )
        install(FILES ${GLSL_SHADERS}
            DESTINATION share/shadercandy/shaders
        )
    else()
        message(STATUS "Linux screensaver sources not found. Set BUILD_SCREENSAVER_LINUX=OFF to disable.")
        set(BUILD_SCREENSAVER_LINUX OFF CACHE BOOL "Build Linux X11 screensaver" FORCE)
    endif()
endif()

# Test executable
if(BUILD_TESTS)
    set(TEST_SOURCES
        tests/TestFramework.cpp
    )
    
    if(MACOS)
        list(APPEND TEST_SOURCES tests/main.mm)
        list(APPEND TEST_SOURCES src/platform/macos/MacOSMetalViewAdapter.mm)
    else()
        list(APPEND TEST_SOURCES tests/main.cpp)
    endif()
    
    add_executable(shadercandy-test ${TEST_SOURCES})
    target_link_libraries(shadercandy-test PRIVATE
        shadercandy_core
    )
    
    if(MACOS AND BUILD_METAL)
        target_link_libraries(shadercandy-test PRIVATE 
            shadercandy_metal
            shadercandy_audio
            ${METAL_FRAMEWORK}
            ${METALKIT_FRAMEWORK}
            ${QUARTZCORE_FRAMEWORK}
            ${SCREENSAVER_FRAMEWORK}
            ${AVFOUNDATION_FRAMEWORK}
            ${ACCELERATE_FRAMEWORK}
            ${COREMEDIA_FRAMEWORK}
            "-framework Foundation"
            "-framework AppKit"
        )
    endif()
    
    if(BUILD_OPENGL)
        target_link_libraries(shadercandy-test PRIVATE shadercandy_gl)
    endif()
endif()

# Copy shaders to build directory
# Copy shaders to build directory for testing
file(GLOB_RECURSE SHADER_FILES
    RELATIVE ${CMAKE_SOURCE_DIR}/shaders
    shaders/*.glsl
    shaders/*.frag
    shaders/*.metal
)

foreach(shader ${SHADER_FILES})
    get_filename_component(shader_dir ${shader} DIRECTORY)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/shaders/${shader_dir})
    configure_file(shaders/${shader} ${CMAKE_BINARY_DIR}/shaders/${shader} COPYONLY)
endforeach()

# Install scripts
install(FILES
    install/install_macos.sh
    install/install_linux.sh
    DESTINATION share/shadercandy
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE
                WORLD_READ WORLD_EXECUTE
)

# Print configuration
message(STATUS "")
message(STATUS "ShaderCandy Configuration:")
message(STATUS "  Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "  Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "  Metal backend: ${BUILD_METAL}")
message(STATUS "  OpenGL backend: ${BUILD_OPENGL}")
message(STATUS "  macOS screensaver: ${BUILD_SCREENSAVER_MACOS}")
message(STATUS "  Linux screensaver: ${BUILD_SCREENSAVER_LINUX}")
message(STATUS "  Tests: ${BUILD_TESTS}")
message(STATUS "")
