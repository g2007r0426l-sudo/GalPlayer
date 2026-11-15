// =============================================================================
// KRKRDSPConfigIos.cpp —— 变声 DSP 桩 + IndividualConfigManager 实现
//
//  1) tRisaPhaseVocoderDSP：本 TU 自带最小类声明（与上游同名同签名），
//     避开上游头里的 RingBuffer 对象成员；功能是变速/变调，播放不需要，静音桩。
//     注意：上游 PhaseVocoderDSP.cpp 未参与编译（malloc.h 不可用），无 ODR 冲突。
//  2) IndividualConfigManager：每游戏配置，内存版（原实现依赖 cocos FileUtils）
// =============================================================================
#include <cstring>
#include <string>
#include <vector>

#include "GlobalConfigManager.h"
#include "IndividualConfigManager.h"

// ---------------------------------------------------------------------------
// tRisaPhaseVocoderDSP —— 最小类声明 + 静音桩
// ---------------------------------------------------------------------------
class tRisaPhaseVocoderDSP {
public:
    tRisaPhaseVocoderDSP(unsigned int framesize, unsigned int frequency, unsigned int channels);
    ~tRisaPhaseVocoderDSP();
    void SetTimeScale(float scale);
    void SetFrequencyScale(float scale);
    void SetOverSampling(unsigned int sampling);
    unsigned long GetInputFreeSize();
    unsigned long GetOutputReadySize();
    unsigned long GetInputBuffer(unsigned long, float *&, unsigned long &, float *&, unsigned long &);
    unsigned long GetOutputBuffer(unsigned long, const float *&, unsigned long &, const float *&, unsigned long &);
    void Process();
};

tRisaPhaseVocoderDSP::tRisaPhaseVocoderDSP(unsigned int, unsigned int, unsigned int) {}
tRisaPhaseVocoderDSP::~tRisaPhaseVocoderDSP() {}
void tRisaPhaseVocoderDSP::SetTimeScale(float) {}
void tRisaPhaseVocoderDSP::SetFrequencyScale(float) {}
void tRisaPhaseVocoderDSP::SetOverSampling(unsigned int) {}
unsigned long tRisaPhaseVocoderDSP::GetInputFreeSize() { return (unsigned long)-1; }
unsigned long tRisaPhaseVocoderDSP::GetOutputReadySize() { return 0; }
unsigned long tRisaPhaseVocoderDSP::GetInputBuffer(unsigned long, float *&buf, unsigned long &size,
                                                   float *&, unsigned long &) {
    buf = nullptr; size = 0; return 0;
}
unsigned long tRisaPhaseVocoderDSP::GetOutputBuffer(unsigned long, const float *&buf, unsigned long &size,
                                                    const float *&, unsigned long &) {
    buf = nullptr; size = 0; return 0;
}
void tRisaPhaseVocoderDSP::Process() {}

// ---------------------------------------------------------------------------
// IndividualConfigManager —— 内存版
// ---------------------------------------------------------------------------
void IndividualConfigManager::Clear() { AllConfig.clear(); ConfigUpdated = false; }

std::string IndividualConfigManager::GetFilePath() { return CurrentPath; }

IndividualConfigManager *IndividualConfigManager::GetInstance() {
    static IndividualConfigManager inst;   // 隐式默认构造
    return &inst;
}

bool IndividualConfigManager::CheckExistAt(const std::string &folder) { (void)folder; return false; }
bool IndividualConfigManager::CreatePreferenceAt(const std::string &folder) { CurrentPath = folder; return true; }
bool IndividualConfigManager::UsePreferenceAt(const std::string &folder) { CurrentPath = folder; return true; }

template<> bool IndividualConfigManager::GetValue<bool>(const std::string &name, const bool &defVal) {
    return iSysConfigManager::GetValue<bool>(name, defVal);
}
template<> int IndividualConfigManager::GetValue<int>(const std::string &name, const int &defVal) {
    return iSysConfigManager::GetValue<int>(name, defVal);
}
template<> float IndividualConfigManager::GetValue<float>(const std::string &name, const float &defVal) {
    return iSysConfigManager::GetValue<float>(name, defVal);
}
template<> std::string IndividualConfigManager::GetValue<std::string>(const std::string &name,
                                                                      const std::string &defVal) {
    return iSysConfigManager::GetValue<std::string>(name, defVal);
}

std::vector<std::string> IndividualConfigManager::GetCustomArgumentsForPush() {
    return iSysConfigManager::GetCustomArgumentsForPush();
}
