cmake_minimum_required(VERSION 3.10)
project(uvs_native_android)

add_library(uvs_android SHARED
    src/main/cpp/uvs_android_jni.cpp
)

find_library(log-lib log)
find_library(mediandk-lib mediandk)

target_link_libraries(uvs_android
    ${log-lib}
    ${mediandk-lib}
)
