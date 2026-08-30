cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. Add sources to be compiled here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "run_loop.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings.
apply_standard_settings(${BINARY_NAME})

# Add dependency libraries and include directories.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Pass application attributes to the builder.
target_compile_definitions(${BINARY_NAME} PRIVATE
  "NOMINMAX"
  "UNICODE"
  "_UNICODE"
)

