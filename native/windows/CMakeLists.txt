cmake_minimum_required(VERSION 3.14)
project(uvs_windows LANGUAGES CXX)

set(BINARY_NAME "universal_video_studio")

add_executable(${BINARY_NAME} WIN32
  "runner/main.cpp"
  "runner/flutter_window.cpp"
  "runner/run_loop.cpp"
  "runner/utils.cpp"
)

target_compile_features(${BINARY_NAME} PRIVATE cxx_std_17)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
