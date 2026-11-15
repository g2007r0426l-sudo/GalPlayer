// =============================================================================
// KRKRDSPConfigIos.cpp —— 变声 DSP 桩 + IndividualConfigManager 实现
//
//  1) tRisaPhaseVocoderDSP：变速/变调用（KAG 的音效可选功能），iOS 先静音桩
//     成员名/签名严格按 sound/PhaseVocoderDSP.h
//  2) IndividualConfigManager：每游戏配置，内存版（原实现依赖 cocos FileUtils）
// =============================================================================
#include <cstring>
#include <string>
#include <vector>

#include "PhaseVocoderDSP.h"
#include "GlobalConfigManager.h"
#include "IndividualConfigManager.h"

// ---------------------------------------------------------------------------
// tRisaPhaseVocoderDSP —— 静音桩
// ---------------------------------------------------------------------------
tRisaPhaseVocoderDSP::tRisaPhaseVocoderDSP(unsigned int frameSize, unsigned int overSampling,
                                           unsigned int channels) {
    AnalWork = nullptr; SynthWork = nullptr;
    LastAnalPhase = nullptr; LastSynthPhase = nullptr;
    FFTWorkIp = nullptr; FFTWorkW = nullptr;
    InputWindow = nullptr; OutputWindow = nullptr;
    FrameSize = frameSize;
    OverSampling = overSampling;
    Channels = channels;
    InputHopSize = FrameSize / (OverSampling ? OverSampling : 1);
    OutputHopSize = InputHopSize;
    TimeScale = 1.0f;
    FrequencyScale = 1.0f;
}

tRisaPhaseVocoderDSP::~tRisaPhaseVocoderDSP() {}

void tRisaPhaseVocoderDSP::SetTimeScale(float scale) {
    TimeScale = scale;
    OutputHopSize = (unsigned int)(InputHopSize * TimeScale);
    if (OutputHopSize == 0) OutputHopSize = InputHopSize;
}

void tRisaPhaseVocoderDSP::SetFrequencyScale(float scale) { FrequencyScale = scale; }

void tRisaPhaseVocoderDSP::SetOverSampling(unsigned int sampling) {
    OverSampling = sampling;
    InputHopSize = FrameSize / (OverSampling ? OverSampling : 1);
    OutputHopSize = (unsigned int)(InputHopSize * TimeScale);
    if (OutputHopSize == 0) OutputHopSize = InputHopSize;
}

unsigned long tRisaPhaseVocoderDSP::GetInputFreeSize() { return (unsigned long)-1; }
unsigned long tRisaPhaseVocoderDSP::GetOutputReadySize() { return 0; }

unsigned long tRisaPhaseVocoderDSP::GetInputBuffer(unsigned long, float *&buf, unsigned long &size,
                                                   float *&, unsigned long &) {
    buf = nullptr;
    size = 0;
    return 0;
}

unsigned long tRisaPhaseVocoderDSP::GetOutputBuffer(unsigned long, const float *&buf, unsigned long &size,
                                                    const float *&, unsigned long &) {
    buf = nullptr;
    size = 0;
    return 0;
}

void tRisaPhaseVocoderDSP::Process() {}

// ---------------------------------------------------------------------------
// IndividualConfigManager —— 内存版
// ---------------------------------------------------------------------------
IndividualConfigManager::IndividualConfigManager() { Initialize(); }

void IndividualConfigManager::Clear() { AllConfig.clear(); ConfigUpdated = false; }

std::string IndividualConfigManager::GetFilePath() { return CurrentPath; }

IndividualConfigManager *IndividualConfigManager::GetInstance() {
    static IndividualConfigManager *inst = new IndividualConfigManager();
    return inst;
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
