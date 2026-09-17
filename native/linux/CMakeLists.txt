cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

set(BINARY_NAME "universal_video_studio")

add_executable(${BINARY_NAME}
  "main.cc"
)

target_compile_features(${BINARY_NAME} PRIVATE cxx_std_14)
target_link_libraries(${BINARY_NAME} PRIVATE pthread)
