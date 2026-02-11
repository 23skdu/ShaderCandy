cmake_minimum_required(VERSION 3.20)
project(ShaderCandy VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
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
)

set(CORE_HEADERS
    src/core/ShaderManager.h
    src/core/UniformBuffer.h
    src/core/PerformanceMonitor.h
    src/core/MathUtils.h
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

# macOS Metal Backend
if(MACOS AND BUILD_METAL)
    enable_language(OBJCXX)
    
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
    
    set(METAL_SOURCES
        src/metal/MetalRenderer.mm
        src/metal/MetalShaderCompiler.mm
    )
    
    add_library(shadercandy_metal STATIC ${METAL_SOURCES})
    target_include_directories(shadercandy_metal PUBLIC src/metal)
    target_link_libraries(shadercandy_metal PUBLIC
        shadercandy_core
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${QUARTZCORE_FRAMEWORK}
    )
    
    # Compile Metal shaders
    set(METAL_SHADERS
        shaders/base/common.metal
        shaders/effects/nebula.metal
        shaders/effects/raymarch.metal
        shaders/effects/fractal.metal
    )
    
    set(METAL_LIB ${CMAKE_BINARY_DIR}/default.metallib)
    add_custom_command(
        OUTPUT ${METAL_LIB}
        COMMAND xcrun -sdk macosx metal -c ${METAL_SHADERS} -o ${CMAKE_BINARY_DIR}/shaders.air
        COMMAND xcrun -sdk macosx metallib ${CMAKE_BINARY_DIR}/shaders.air -o ${METAL_LIB}
        DEPENDS ${METAL_SHADERS}
        COMMENT "Compiling Metal shaders"
    )
    add_custom_target(metal_shaders DEPENDS ${METAL_LIB})
endif()

# OpenGL Backend
if(BUILD_OPENGL)
    find_package(OpenGL REQUIRED)
    
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
endif()

# macOS Screensaver
if(MACOS AND BUILD_SCREENSAVER_MACOS)
    set(SCREENSAVER_SOURCES
        src/platform/macos/ShaderCandyView.mm
    )
    
    find_library(SCREENSAVER_FRAMEWORK ScreenSaver REQUIRED)
    
    add_bundle(ShaderCandy SCREENSAVER
        ${SCREENSAVER_SOURCES}
    )
    
    set_target_properties(ShaderCandy PROPERTIES
        BUNDLE_EXTENSION saver
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/src/platform/macos/Info.plist.in
    )
    
    target_link_libraries(ShaderCandy PRIVATE
        shadercandy_metal
        shadercandy_core
        ${SCREENSAVER_FRAMEWORK}
    )
    
    add_dependencies(ShaderCandy metal_shaders)
endif()

# Linux X11 Screensaver
if(LINUX AND BUILD_SCREENSAVER_LINUX)
    set(LINUX_SCREENSAVER_SOURCES
        src/platform/linux/screensaver.cpp
    )
    
    add_executable(shadercandy-screensaver ${LINUX_SCREENSAVER_SOURCES})
    target_link_libraries(shadercandy-screensaver PRIVATE
        shadercandy_gl
        shadercandy_core
        ${X11_LIBRARIES}
        ${X11_Xmu_LIB}
        ${XSS_LIB}
        GL
    )
    
    # Install
    install(TARGETS shadercandy-screensaver
        RUNTIME DESTINATION bin
    )
    
    install(FILES
        shaders/effects/nebula.frag
        shaders/effects/raymarch_sculpture.frag
        shaders/effects/mandelbulb.frag
        shaders/effects/reaction_diffusion.frag
        DESTINATION share/shadercandy/shaders
    )
endif()

# Test executable
if(BUILD_TESTS)
    set(TEST_SOURCES
        tests/main.cpp
        tests/shader_tests.cpp
        tests/performance_tests.cpp
    )
    
    add_executable(shadercandy-test ${TEST_SOURCES})
    target_link_libraries(shadercandy-test PRIVATE
        shadercandy_core
    )
    
    if(MACOS AND BUILD_METAL)
        target_link_libraries(shadercandy-test PRIVATE shadercandy_metal)
    endif()
    
    if(BUILD_OPENGL)
        target_link_libraries(shadercandy-test PRIVATE shadercandy_gl)
    endif()
endif()

# Copy shaders to build directory
file(GLOB SHADER_FILES
    shaders/base/*.glsl
    shaders/effects/*.frag
)

foreach(shader ${SHADER_FILES})
    configure_file(${shader} ${CMAKE_BINARY_DIR}/shaders/ COPYONLY)
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
