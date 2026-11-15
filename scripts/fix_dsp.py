# -*- coding: utf-8 -*-
"""DSP 桩构造函数改用初始化列表（类含 const 成员）"""
import pathlib

p = pathlib.Path(r"engines/tjs2/KRKRDSPConfigIos.cpp")
s = p.read_text(encoding="utf-8")

old = '''tRisaPhaseVocoderDSP::tRisaPhaseVocoderDSP(unsigned int frameSize, unsigned int overSampling,
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
}'''

new = '''tRisaPhaseVocoderDSP::tRisaPhaseVocoderDSP(unsigned int frameSize, unsigned int overSampling,
                                           unsigned int channels)
    : AnalWork(nullptr), SynthWork(nullptr), LastAnalPhase(nullptr), LastSynthPhase(nullptr),
      FFTWorkIp(nullptr), FFTWorkW(nullptr), InputWindow(nullptr), OutputWindow(nullptr),
      FrameSize(frameSize), OverSampling(overSampling), Frequency(0), Channels(channels),
      InputHopSize(frameSize / (overSampling ? overSampling : 1)),
      OutputHopSize(frameSize / (overSampling ? overSampling : 1)),
      TimeScale(1.0f), FrequencyScale(1.0f) {}'''

assert old in s, "ctor anchor missing"
s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("ctor fixed")
