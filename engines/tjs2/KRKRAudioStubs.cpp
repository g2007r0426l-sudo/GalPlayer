// =============================================================================
// KRKRAudioStubs.cpp —— OpenAL / 变声 DSP 的 iOS 静音实现
//
// iOS 17 SDK 已移除 OpenAL.framework，而 Kirikinx2 的声音层直接调用 AL。
// 这里用 extern "C" 提供同名同参的静音桩：引擎可以正常链接与运行，
// 音频暂时静音。后续可替换为 AVAudioEngine / SDL_mixer 实现。
// =============================================================================
#include <cstddef>
#include <cstdint>

extern "C" {

// ---------------- alc*（设备/上下文） ----------------
typedef void *ALCdevice;
typedef void *ALCcontext;
typedef void *ALCchar;

ALCdevice  alcOpenDevice(const char *devicename) { (void)devicename; return (ALCdevice)1; }
char       alcCloseDevice(ALCdevice dev) { (void)dev; return 1; }
ALCcontext alcCreateContext(ALCdevice dev, const int *attrlist) { (void)dev; (void)attrlist; return (ALCcontext)1; }
char       alcMakeContextCurrent(ALCcontext ctx) { (void)ctx; return 1; }
void       alcDestroyContext(ALCcontext ctx) { (void)ctx; }
const char *alcGetString(ALCdevice dev, int param) { (void)dev; (void)param; return "GalPlayer"; }
char       alcIsExtensionPresent(ALCdevice dev, const char *extname) { (void)dev; (void)extname; return 0; }
int        alcGetError(ALCdevice dev) { (void)dev; return 0; }

// ---------------- al*（缓冲区/源/监听器） ----------------
void alGenBuffers(int n, unsigned int *buffers) { for (int i = 0; i < n; ++i) buffers[i] = (unsigned)(i + 1); }
void alDeleteBuffers(int n, const unsigned int *buffers) { (void)n; (void)buffers; }
void alBufferData(unsigned int bid, int format, const void *data, int size, int freq) {
    (void)bid; (void)format; (void)data; (void)size; (void)freq;
}
void alGenSources(int n, unsigned int *sources) { for (int i = 0; i < n; ++i) sources[i] = (unsigned)(i + 1); }
void alDeleteSources(int n, const unsigned int *sources) { (void)n; (void)sources; }
void alSourcePlay(unsigned int sid) { (void)sid; }
void alSourcePause(unsigned int sid) { (void)sid; }
void alSourceStop(unsigned int sid) { (void)sid; }
void alSourceRewind(unsigned int sid) { (void)sid; }
void alSourcei(unsigned int sid, int param, int value) { (void)sid; (void)param; (void)value; }
void alSourcef(unsigned int sid, int param, float value) { (void)sid; (void)param; (void)value; }
void alSource3f(unsigned int sid, int param, float v1, float v2, float v3) {
    (void)sid; (void)param; (void)v1; (void)v2; (void)v3;
}
void alGetSourcei(unsigned int sid, int param, int *value) { (void)sid; (void)param; if (value) *value = 0; }
void alGetSourcef(unsigned int sid, int param, float *value) { (void)sid; (void)param; if (value) *value = 0.f; }
void alGetSourcefv(unsigned int sid, int param, float *values) { (void)sid; (void)param; if (values) values[0] = 0.f; }
void alSourceQueueBuffers(unsigned int sid, int n, const unsigned int *bids) { (void)sid; (void)n; (void)bids; }
void alSourceUnqueueBuffers(unsigned int sid, int n, unsigned int *bids) { (void)sid; (void)n; (void)bids; }
void alListenerf(int param, float value) { (void)param; (void)value; }
void alListener3f(int param, float v1, float v2, float v3) { (void)param; (void)v1; (void)v2; (void)v3; }
void alGetListenerf(int param, float *value) { (void)param; if (value) *value = 1.f; }
int  alGetError(void) { return 0; }
void alDopplerFactor(float value) { (void)value; }
void alDistanceModel(int model) { (void)model; }

} // extern "C"
