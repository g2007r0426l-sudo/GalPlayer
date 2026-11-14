// =============================================================================
// KR2IOSStubs.cpp — Kirikinux2 iOS 版的对话框/崩溃处理桩
//
// 与 Kirikinux2 的 LinuxFeatureStubs.cpp 同思路：引擎要求的宿主能力在 iOS MVP
// 阶段不可用（GTK 对话框 / fontconfig / 崩溃回溯）时返回非交互值，引擎自带的
// cocos UI（environ/ui）承担绝大多数交互。
// =============================================================================
#include <string>
#include <vector>

// iOS MVP: 消息框返回 -2（引擎按"无 GUI 可用"处理：采用第一个按钮继续）。
// 后续可升级为 UIAlertController 实现。
int KR2IOSMessageBox(const std::string &text, const std::string &caption, const std::vector<std::string> &buttons) {
	(void)text; (void)caption; (void)buttons;
	fprintf(stderr, "[KR2-IOS] MessageBox(未实现 UI): %s | %s\n", caption.c_str(), text.c_str());
	return -2;
}

// 崩溃处理器桩（Linux 版有 in-process 回溯；iOS 由 CrashReporter 系统日志接管）
void TVPLinuxInstallCrashHandler() {}
