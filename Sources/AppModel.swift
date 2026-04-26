import Foundation
import IOKit.pwr_mgt
import SwiftUI

enum SessionMode: String, CaseIterable, Identifiable {
    case timed
    case infinite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timed:
            return "定时"
        case .infinite:
            return "无限"
        }
    }
}

@MainActor
final class AgentDutyStore: ObservableObject {
    @Published var sessionMode: SessionMode
    @Published var durationMinutes: Int
    @Published var experimentalLidCloseMode: Bool

    @Published private(set) var isActive = false
    @Published private(set) var countdownText = "未开启"
    @Published private(set) var subtitleText = "系统允许正常休眠"
    @Published private(set) var lastError: String?
    @Published private(set) var lidCloseStatusText = "未请求"
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatusText = "未启用"

    private let defaults: UserDefaults
    private let lidCloseController = LidCloseController()
    private let launchAtLoginController: LaunchAtLoginController?

    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    private var endDate: Date?
    private var shouldRestoreLidCloseSleepSetting = false
    private var activeSessionID = UUID()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sessionMode = SessionMode(rawValue: defaults.string(forKey: DefaultsKey.sessionMode) ?? "") ?? .timed
        let savedMinutes = defaults.integer(forKey: DefaultsKey.durationMinutes)
        self.durationMinutes = savedMinutes == 0 ? 60 : min(max(savedMinutes, 5), 720)
        self.experimentalLidCloseMode = defaults.bool(forKey: DefaultsKey.experimentalLidCloseMode)
        if #available(macOS 13.0, *) {
            self.launchAtLoginController = LaunchAtLoginController()
        } else {
            self.launchAtLoginController = nil
        }
        refreshLaunchAtLoginStatus()
    }

    var toggleBinding: Binding<Bool> {
        Binding(
            get: { self.isActive },
            set: { isEnabled in
                if isEnabled {
                    self.startSession()
                } else {
                    self.stopSession()
                }
            }
        )
    }

    var menuBarTitle: String {
        if isActive, sessionMode == .timed {
            return countdownText
        }

        return AppIdentity.menuBarName
    }

    func persistMode() {
        defaults.set(sessionMode.rawValue, forKey: DefaultsKey.sessionMode)
    }

    func persistDuration() {
        let clamped = min(max(durationMinutes, 5), 720)
        if clamped != durationMinutes {
            durationMinutes = clamped
            return
        }

        defaults.set(clamped, forKey: DefaultsKey.durationMinutes)
    }

    func persistLidClosePreference() {
        defaults.set(experimentalLidCloseMode, forKey: DefaultsKey.experimentalLidCloseMode)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled == launchAtLoginEnabled {
            return
        }

        guard let launchAtLoginController else {
            lastError = "当前系统不支持开机自启开关。"
            refreshLaunchAtLoginStatus()
            return
        }

        do {
            try launchAtLoginController.setEnabled(enabled)
            lastError = nil
            refreshLaunchAtLoginStatus()

            if launchAtLoginController.status == .requiresApproval {
                launchAtLoginStatusText = "等待系统批准"
            }
        } catch {
            refreshLaunchAtLoginStatus()
            lastError = "开机自启设置失败：\(error.localizedDescription)"
        }
    }

    func openLoginItemsSettings() {
        launchAtLoginController?.openSystemSettings()
    }

    func startSession() {
        guard !isActive else { return }

        do {
            try acquireAssertion()
        } catch {
            lastError = error.localizedDescription
            return
        }

        activeSessionID = UUID()
        isActive = true
        lastError = nil
        shouldRestoreLidCloseSleepSetting = false

        if sessionMode == .timed {
            let totalSeconds = durationMinutes * 60
            endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
            countdownText = formatDuration(totalSeconds)
            subtitleText = "将在 \(formatMinutes(durationMinutes)) 后自动结束"
            startCountdownTimer()
        } else {
            endDate = nil
            countdownText = "无限"
            subtitleText = "保持系统唤醒，直到你手动关闭"
            stopCountdownTimer()
        }

        lidCloseStatusText = experimentalLidCloseMode ? "请求中..." : "未请求"

        guard experimentalLidCloseMode else { return }
        requestLidCloseMode(for: activeSessionID)
    }

    func stopSession() {
        guard isActive else { return }

        isActive = false
        activeSessionID = UUID()
        releaseAssertion()
        stopCountdownTimer()
        endDate = nil
        countdownText = "未开启"
        subtitleText = "系统允许正常休眠"
        lidCloseStatusText = experimentalLidCloseMode ? "正在恢复..." : "未请求"

        guard shouldRestoreLidCloseSleepSetting else {
            shouldRestoreLidCloseSleepSetting = false
            lidCloseStatusText = experimentalLidCloseMode ? "未修改系统设置" : "未请求"
            return
        }

        shouldRestoreLidCloseSleepSetting = false
        restoreLidCloseMode()
    }

    private func acquireAssertion() throws {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "StayAwake active session" as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw CommandFailure(command: "IOPMAssertionCreateWithName", output: "无法创建系统防休眠断言，错误码：\(result)")
        }
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCountdown()
            }
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func tickCountdown() {
        guard isActive, sessionMode == .timed, let endDate else { return }

        let remainingSeconds = Int(ceil(endDate.timeIntervalSinceNow))

        if remainingSeconds <= 0 {
            stopSession()
            return
        }

        countdownText = formatDuration(remainingSeconds)
        subtitleText = "将在 \(formatDuration(remainingSeconds)) 后自动结束"
    }

    private func requestLidCloseMode(for sessionID: UUID) {
        Task.detached { [lidCloseController] in
            do {
                let wasAlreadyDisabled = try lidCloseController.isSleepDisabled()

                if !wasAlreadyDisabled {
                    try lidCloseController.setSleepDisabled(true)
                }

                await MainActor.run {
                    guard self.isActive, self.activeSessionID == sessionID else { return }
                    self.shouldRestoreLidCloseSleepSetting = !wasAlreadyDisabled
                    self.lidCloseStatusText = wasAlreadyDisabled ? "系统已关闭盒盖睡眠" : "已启用实验模式"
                }
            } catch {
                await MainActor.run {
                    guard self.isActive, self.activeSessionID == sessionID else { return }
                    self.lidCloseStatusText = "请求失败"
                    self.lastError = "盒盖模式未启用：\(error.localizedDescription)"
                }
            }
        }
    }

    private func restoreLidCloseMode() {
        Task.detached { [lidCloseController] in
            do {
                try lidCloseController.setSleepDisabled(false)
                await MainActor.run {
                    if !self.isActive {
                        self.lidCloseStatusText = "已恢复默认行为"
                    }
                }
            } catch {
                await MainActor.run {
                    if !self.isActive {
                        self.lidCloseStatusText = "恢复失败"
                        self.lastError = "未能恢复盒盖睡眠设置：\(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func refreshLaunchAtLoginStatus() {
        guard let launchAtLoginController else {
            launchAtLoginEnabled = false
            launchAtLoginStatusText = "当前系统不可用"
            return
        }

        let status = launchAtLoginController.status
        launchAtLoginEnabled = launchAtLoginController.isEnabled

        switch status {
        case .enabled:
            launchAtLoginStatusText = "已启用"
        case .requiresApproval:
            launchAtLoginStatusText = "等待系统批准"
        case .notFound:
            launchAtLoginStatusText = "仅在打包后的 .app 中可用"
        case .notRegistered:
            launchAtLoginStatusText = "未启用"
        @unknown default:
            launchAtLoginStatusText = "状态未知"
        }
    }
}

private enum DefaultsKey {
    static let sessionMode = "sessionMode"
    static let durationMinutes = "durationMinutes"
    static let experimentalLidCloseMode = "experimentalLidCloseMode"
}
