#include <jni.h>
#include <string>

extern "C" JNIEXPORT jstring JNICALL
Java_org_uvs_universal_1video_1studio_MainActivity_stringFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    std::string version = "UVS Android MediaCodec Bridge 0.1.0";
    return env->NewStringUTF(version.c_str());
}
