cmake_minimum_required(VERSION 3.14)
project(nayli_market_desktop LANGUAGES CXX)

set(BINARY_NAME "Nayli Market Desktop")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configure build options.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Configuration type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Compilation flags
if(MSVC)
  add_compile_options(/W4 /WX /wd"4100")
endif()

# Application-level sources & CMake subdirectories
add_subdirectory("runner")

# Generated code and plugins
include(flutter/generated_plugins.cmake)

