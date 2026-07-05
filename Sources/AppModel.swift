import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import SwiftUI

enum SessionScheduleMode: String, CaseIterable, Identifiable {
    case infinite
    case preset
    case custom
    case deadline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .infinite:
            return "无限"
        case .preset:
            return "常用时长"
        case .custom:
            return "自定义"
        case .deadline:
            return "截止日期"
        }
    }
}

enum DurationUnit: String, CaseIterable, Identifiable {
    case minutes
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minutes:
            return "分钟"
        case .hours:
            return "小时"
        }
    }

    var multiplier: Int {
        switch self {
        case .minutes:
            return 1
        case .hours:
            return 60
        }
    }
}

struct DurationPreset: Identifiable, Hashable {
    let minutes: Int

    var id: Int { minutes }
    var title: String { formatMinutes(minutes) }
}

struct BatterySnapshot {
    let percentage: Int?
    let isCharging: Bool
    let isOnBattery: Bool
    let isAvailable: Bool
}

@MainActor
final class AgentDutyStore: ObservableObject {
    let presetOptions = [
        DurationPreset(minutes: 15),
        DurationPreset(minutes: 30),
        DurationPreset(minutes: 60),
        DurationPreset(minutes: 120),
        DurationPreset(minutes: 180),
        DurationPreset(minutes: 360),
    ]

    @Published var scheduleMode: SessionScheduleMode
    @Published var selectedPresetMinutes: Int
    @Published var customDurationText: String
    @Published var customDurationUnit: DurationUnit
    @Published var deadlineDate: Date
    @Published var experimentalLidCloseMode: Bool
    @Published var lowBatteryProtectionEnabled: Bool
    @Published var lowBatteryThreshold: Int

    @Published private(set) var isActive = false
    @Published private(set) var countdownText = "未开启"
    @Published private(set) var subtitleText = "默认：无限运行，直到你手动关闭"
    @Published private(set) var statusHintText = "开启后会持续保持系统唤醒"
    @Published private(set) var lastError: String?
    @Published private(set) var lidCloseStatusText = "未开启"
    @Published private(set) var systemPowerStatusText = "正在读取系统状态"
    @Published private(set) var systemPowerStatusDetailText = "正在检查合盖睡眠设置"
    @Published private(set) var systemPowerStatusUpdatedText = ""
    @Published private(set) var canRestoreSystemSleep = false
    @Published private(set) var isRefreshingSystemPowerStatus = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatusText = "未启用"
    @Published private(set) var batteryStatusText = "正在读取电量状态"
    @Published private(set) var updateStatusText = "正在检查更新"
    @Published private(set) var updateDetailText = "当前版本：--"
    @Published private(set) var canDownloadUpdate = false
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var isDownloadingUpdate = false

    private let defaults: UserDefaults
    private let lidCloseController = LidCloseController()
    private let updateController = UpdateController()
    private let launchAtLoginController: LaunchAtLoginController?

    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    private var batteryTimer: Timer?
    private var endDate: Date?
    private var shouldRestoreLidCloseSleepSetting = false
    private var activeSessionID = UUID()
    private var currentBatterySnapshot = BatterySnapshot(percentage: nil, isCharging: false, isOnBattery: false, isAvailable: false)
    private var availableUpdate: AppUpdateInfo?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.scheduleMode = SessionScheduleMode(rawValue: defaults.string(forKey: DefaultsKey.scheduleMode) ?? "") ?? .infinite

        let savedPreset = defaults.integer(forKey: DefaultsKey.selectedPresetMinutes)
        self.selectedPresetMinutes = [15, 30, 60, 120, 180, 360].contains(savedPreset) ? savedPreset : 60

        let savedCustomDuration = defaults.integer(forKey: DefaultsKey.customDurationValue)
        self.customDurationText = String(savedCustomDuration == 0 ? 90 : savedCustomDuration)
        self.customDurationUnit = DurationUnit(rawValue: defaults.string(forKey: DefaultsKey.customDurationUnit) ?? "") ?? .minutes

        let savedDeadlineInterval = defaults.double(forKey: DefaultsKey.deadlineDate)
        let savedDeadline = savedDeadlineInterval > 0 ? Date(timeIntervalSince1970: savedDeadlineInterval) : Self.defaultDeadlineDate()
        self.deadlineDate = max(savedDeadline, Date().addingTimeInterval(60))

        self.experimentalLidCloseMode = defaults.bool(forKey: DefaultsKey.experimentalLidCloseMode)

        self.lowBatteryProtectionEnabled = defaults.bool(forKey: DefaultsKey.lowBatteryProtectionEnabled)
        let savedThreshold = defaults.integer(forKey: DefaultsKey.lowBatteryThreshold)
        self.lowBatteryThreshold = savedThreshold == 0 ? 20 : min(max(savedThreshold, 5), 50)

        if #available(macOS 13.0, *) {
            self.launchAtLoginController = LaunchAtLoginController()
        } else {
            self.launchAtLoginController = nil
        }

        refreshLaunchAtLoginStatus()
        refreshBatterySnapshot()
        recoverLingeringLidCloseOverrideIfNeeded()
        experimentalLidCloseMode = false
        defaults.set(false, forKey: DefaultsKey.experimentalLidCloseMode)
        refreshSystemPowerStatus()
        refreshUpdatePresentation()
        checkForUpdates(silent: true)
        refreshPresentation()
        startBatteryTimer()
    }

    var toggleBinding: Binding<Bool> {
        Binding(
            get: { self.isActive },
            set: { isEnabled in
                if isEnabled {
                    self.startSession()
                } else {
                    self.stopSession(reason: nil)
                }
            }
        )
    }

    var menuBarTitle: String {
        if isActive {
            return endDate == nil ? "∞" : countdownText
        }

        return AppIdentity.menuBarName
    }

    var canShowLoginSettingsShortcut: Bool {
        launchAtLoginStatusText == "等待系统批准" || launchAtLoginStatusText == "仅在打包后的 .app 中可用"
    }

    var customDurationValidationMessage: String? {
        guard let value = Int(customDurationText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            return "请输入大于 0 的时长。"
        }

        let totalMinutes = value * customDurationUnit.multiplier
        guard totalMinutes <= 7 * 24 * 60 else {
            return "自定义时长请控制在 7 天以内。"
        }

        return nil
    }

    func setScheduleMode(_ mode: SessionScheduleMode) {
        guard !isActive else { return }
        scheduleMode = mode
        defaults.set(mode.rawValue, forKey: DefaultsKey.scheduleMode)
        refreshPresentation()
    }

    func selectPreset(_ minutes: Int) {
        guard !isActive else { return }
        selectedPresetMinutes = minutes
        defaults.set(minutes, forKey: DefaultsKey.selectedPresetMinutes)
        refreshPresentation()
    }

    func setCustomDurationText(_ text: String) {
        guard !isActive else { return }
        let filtered = text.filter(\.isNumber)
        customDurationText = filtered
        defaults.set(Int(filtered) ?? 0, forKey: DefaultsKey.customDurationValue)
        refreshPresentation()
    }

    func setCustomDurationUnit(_ unit: DurationUnit) {
        guard !isActive else { return }
        customDurationUnit = unit
        defaults.set(unit.rawValue, forKey: DefaultsKey.customDurationUnit)
        refreshPresentation()
    }

    func setDeadlineDate(_ date: Date) {
        guard !isActive else { return }
        deadlineDate = date
        defaults.set(date.timeIntervalSince1970, forKey: DefaultsKey.deadlineDate)
        refreshPresentation()
    }

    func setExperimentalLidCloseMode(_ enabled: Bool) {
        guard isActive else {
            experimentalLidCloseMode = false
            defaults.set(false, forKey: DefaultsKey.experimentalLidCloseMode)
            refreshLidCloseStatusText()
            return
        }

        let wasEnabled = experimentalLidCloseMode
        experimentalLidCloseMode = enabled
        defaults.set(enabled, forKey: DefaultsKey.experimentalLidCloseMode)

        if enabled && !wasEnabled {
            lidCloseStatusText = "请求中..."
            requestLidCloseMode(for: activeSessionID)
        } else if wasEnabled && !enabled {
            lidCloseStatusText = "正在恢复..."
            restoreLidCloseMode()
        } else {
            refreshLidCloseStatusText()
        }
    }

    func setLowBatteryProtectionEnabled(_ enabled: Bool) {
        lowBatteryProtectionEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.lowBatteryProtectionEnabled)
        evaluateBatteryProtection()
    }

    func setLowBatteryThreshold(_ threshold: Int) {
        lowBatteryThreshold = min(max(threshold, 5), 50)
        defaults.set(lowBatteryThreshold, forKey: DefaultsKey.lowBatteryThreshold)
        evaluateBatteryProtection()
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

    func checkForUpdates(silent: Bool = false) {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        if !silent {
            updateStatusText = "正在检查更新"
            updateDetailText = "正在连接 GitHub..."
        }

        Task {
            do {
                let result = try await updateController.checkForUpdate()
                availableUpdate = result.update
                canDownloadUpdate = result.update != nil

                if let update = result.update {
                    updateStatusText = "发现新版 \(update.version)"
                    updateDetailText = "点击下载后会保存到 Downloads，并自动打开安装包。"
                } else {
                    updateStatusText = "已是最新版本"
                    updateDetailText = "当前版本：\(updateController.currentVersion)"
                }

                isCheckingForUpdates = false
            } catch {
                if !silent {
                    updateStatusText = "检查失败"
                    updateDetailText = "暂时无法连接 GitHub，请稍后再试。"
                } else {
                    refreshUpdatePresentation()
                }

                canDownloadUpdate = false
                isCheckingForUpdates = false
            }
        }
    }

    func downloadLatestUpdate() {
        guard let availableUpdate, !isDownloadingUpdate else { return }

        isDownloadingUpdate = true
        updateStatusText = "正在下载 \(availableUpdate.version)"
        updateDetailText = "下载完成后会自动打开安装包。"

        Task {
            do {
                let fileURL = try await updateController.download(availableUpdate)
                updateController.openDownloadedUpdate(at: fileURL)
                updateStatusText = "已下载新版 \(availableUpdate.version)"
                updateDetailText = "安装包已打开。把 app 拖到 Applications 完成更新。"
                isDownloadingUpdate = false
            } catch {
                updateStatusText = "下载失败"
                updateDetailText = "请检查网络后重试。"
                isDownloadingUpdate = false
            }
        }
    }

    func refreshSystemPowerStatus() {
        guard !isRefreshingSystemPowerStatus else { return }

        isRefreshingSystemPowerStatus = true
        systemPowerStatusUpdatedText = "检查中..."

        Task.detached { [lidCloseController] in
            do {
                let snapshot = try lidCloseController.readPowerSettingsSnapshot()
                await MainActor.run {
                    self.applySystemPowerSnapshot(snapshot)
                    self.isRefreshingSystemPowerStatus = false
                }
            } catch {
                await MainActor.run {
                    self.systemPowerStatusText = "读取失败"
                    self.systemPowerStatusDetailText = "暂时没读到系统设置，请稍后再试。"
                    self.systemPowerStatusUpdatedText = ""
                    self.canRestoreSystemSleep = false
                    self.isRefreshingSystemPowerStatus = false
                }
            }
        }
    }

    func restoreSystemSleepNow() {
        guard !isRefreshingSystemPowerStatus else { return }

        isRefreshingSystemPowerStatus = true
        systemPowerStatusText = "正在恢复合盖睡眠"
        systemPowerStatusDetailText = "macOS 会弹出管理员授权。"
        systemPowerStatusUpdatedText = ""

        Task.detached { [lidCloseController] in
            do {
                try lidCloseController.setSleepDisabled(false)
                UserDefaults.standard.set(false, forKey: DefaultsKey.managedLidCloseSleepOverride)
                let snapshot = try lidCloseController.readPowerSettingsSnapshot()

                await MainActor.run {
                    self.shouldRestoreLidCloseSleepSetting = false
                    self.refreshLidCloseStatusText()
                    self.applySystemPowerSnapshot(snapshot)
                    self.isRefreshingSystemPowerStatus = false
                    self.lastError = nil
                }
            } catch {
                await MainActor.run {
                    self.systemPowerStatusText = "恢复失败"
                    self.systemPowerStatusDetailText = "没有完成恢复，请确认管理员授权后再试。"
                    self.systemPowerStatusUpdatedText = ""
                    self.isRefreshingSystemPowerStatus = false
                    self.lastError = "未能恢复盒盖睡眠设置：\(error.localizedDescription)"
                }
            }
        }
    }

    func startSession() {
        guard !isActive else { return }

        refreshBatterySnapshot()

        do {
            let requestedEndDate = try resolveRequestedEndDate()

            if shouldStopForLowBattery(currentBatterySnapshot) {
                if let percentage = currentBatterySnapshot.percentage {
                    lastError = "当前电量仅 \(percentage)%，低于你设置的 \(lowBatteryThreshold)% 阈值，未开启防休眠。"
                } else {
                    lastError = "当前电量状态不适合开启防休眠。"
                }
                return
            }

            try acquireAssertion()

            activeSessionID = UUID()
            isActive = true
            lastError = nil
            shouldRestoreLidCloseSleepSetting = false
            endDate = requestedEndDate

            if endDate == nil {
                stopCountdownTimer()
            } else {
                startCountdownTimer()
            }

            refreshPresentation()

            refreshLidCloseStatusText()
            refreshSystemPowerStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopSession(reason: String?) {
        guard isActive else {
            if let reason {
                lastError = reason
            }
            refreshPresentation()
            return
        }

        let wasExperimentalLidCloseMode = experimentalLidCloseMode

        isActive = false
        activeSessionID = UUID()
        releaseAssertion()
        stopCountdownTimer()
        endDate = nil
        experimentalLidCloseMode = false
        defaults.set(false, forKey: DefaultsKey.experimentalLidCloseMode)
        lidCloseStatusText = wasExperimentalLidCloseMode ? "正在恢复..." : "未开启"
        lastError = reason

        guard shouldRestoreLidCloseModeAfterSession || wasExperimentalLidCloseMode else {
            shouldRestoreLidCloseSleepSetting = false
            refreshLidCloseStatusText()
            refreshPresentation()
            refreshSystemPowerStatus()
            return
        }

        shouldRestoreLidCloseSleepSetting = false
        refreshPresentation()
        restoreLidCloseMode()
    }

    func prepareForTermination() {
        stopBatteryTimer()

        if isActive {
            isActive = false
            activeSessionID = UUID()
            releaseAssertion()
            stopCountdownTimer()
            endDate = nil
        }

        if shouldRestoreLidCloseModeAfterSession {
            shouldRestoreLidCloseSleepSetting = false
            restoreLidCloseModeSynchronously()
        }
    }

    private func acquireAssertion() throws {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "\(AppIdentity.productName) active session" as CFString,
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

    private func startBatteryTimer() {
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBatterySnapshot()
                self?.evaluateBatteryProtection()
                self?.refreshSystemPowerStatus()
            }
        }
    }

    private func stopBatteryTimer() {
        batteryTimer?.invalidate()
        batteryTimer = nil
    }

    private func tickCountdown() {
        guard isActive else { return }

        if let endDate {
            let remainingSeconds = Int(ceil(endDate.timeIntervalSinceNow))

            if remainingSeconds <= 0 {
                stopSession(reason: nil)
                return
            }
        }

        refreshPresentation()
    }

    private func resolveRequestedEndDate() throws -> Date? {
        switch scheduleMode {
        case .infinite:
            return nil
        case .preset:
            return Date().addingTimeInterval(TimeInterval(selectedPresetMinutes * 60))
        case .custom:
            guard let minutes = customDurationMinutes else {
                throw CommandFailure(command: "customDuration", output: customDurationValidationMessage ?? "请输入有效的自定义时长。")
            }
            return Date().addingTimeInterval(TimeInterval(minutes * 60))
        case .deadline:
            guard deadlineDate > Date().addingTimeInterval(30) else {
                throw CommandFailure(command: "deadlineDate", output: "截止时间需要晚于当前时间。")
            }
            return deadlineDate
        }
    }

    private var customDurationMinutes: Int? {
        guard let value = Int(customDurationText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            return nil
        }

        let totalMinutes = value * customDurationUnit.multiplier
        guard totalMinutes <= 7 * 24 * 60 else {
            return nil
        }

        return totalMinutes
    }

    private func refreshPresentation() {
        if isActive {
            if let endDate {
                let remainingSeconds = max(Int(ceil(endDate.timeIntervalSinceNow)), 0)
                countdownText = formatDuration(remainingSeconds)
                subtitleText = "运行到 \(formatDeadline(endDate))"
                statusHintText = "剩余 \(formatDuration(remainingSeconds))，到点后自动关闭防休眠"
            } else {
                countdownText = "∞"
                subtitleText = "无限模式运行中"
                statusHintText = "保持系统唤醒，直到你手动关闭"
            }
            return
        }

        countdownText = "未开启"

        switch scheduleMode {
        case .infinite:
            subtitleText = "默认：无限运行，直到你手动关闭"
            statusHintText = "开启后会持续保持系统唤醒"
        case .preset:
            subtitleText = "默认：运行 \(formatMinutes(selectedPresetMinutes))"
            statusHintText = "开始后会自动倒计时，到点后结束"
        case .custom:
            if let minutes = customDurationMinutes {
                subtitleText = "默认：运行 \(formatMinutes(minutes))"
                statusHintText = "你可以输入更细的自定义时长"
            } else {
                subtitleText = "请先输入有效的自定义时长"
                statusHintText = "支持分钟或小时"
            }
        case .deadline:
            subtitleText = "默认：持续到 \(formatDeadline(deadlineDate))"
            statusHintText = "适合“直到明天 10:00”这类固定截止时间"
        }
    }

    private func requestLidCloseMode(for sessionID: UUID) {
        Task.detached { [lidCloseController] in
            do {
                let wasAlreadyDisabled = try lidCloseController.isSleepDisabled()
                var didChangeSleepSetting = false

                if !wasAlreadyDisabled {
                    try lidCloseController.setSleepDisabled(true)
                    didChangeSleepSetting = true
                    UserDefaults.standard.set(true, forKey: DefaultsKey.managedLidCloseSleepOverride)
                }

                let shouldRestoreIfSessionEnded = didChangeSleepSetting

                let shouldRestoreImmediately = await MainActor.run { () -> Bool in
                    guard self.isActive, self.activeSessionID == sessionID else {
                        return shouldRestoreIfSessionEnded
                    }
                    self.shouldRestoreLidCloseSleepSetting = !wasAlreadyDisabled
                    self.refreshLidCloseStatusText(systemSleepAlreadyDisabled: wasAlreadyDisabled)
                    self.refreshSystemPowerStatus()
                    return false
                }

                guard shouldRestoreImmediately else { return }

                try lidCloseController.setSleepDisabled(false)
                UserDefaults.standard.set(false, forKey: DefaultsKey.managedLidCloseSleepOverride)

                await MainActor.run {
                    if !self.isActive {
                        self.refreshLidCloseStatusText()
                    }
                    self.refreshSystemPowerStatus()
                }
            } catch {
                await MainActor.run {
                    guard self.isActive, self.activeSessionID == sessionID else { return }
                    self.experimentalLidCloseMode = false
                    self.defaults.set(false, forKey: DefaultsKey.experimentalLidCloseMode)
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
                UserDefaults.standard.set(false, forKey: DefaultsKey.managedLidCloseSleepOverride)
                await MainActor.run {
                    self.refreshLidCloseStatusText()
                    self.refreshSystemPowerStatus()
                }
            } catch {
                await MainActor.run {
                    self.lidCloseStatusText = "恢复失败"
                    self.lastError = "未能恢复盒盖睡眠设置：\(error.localizedDescription)"
                }
            }
        }
    }

    private var hasManagedLidCloseSleepOverride: Bool {
        defaults.bool(forKey: DefaultsKey.managedLidCloseSleepOverride)
    }

    private var shouldRestoreLidCloseModeAfterSession: Bool {
        shouldRestoreLidCloseSleepSetting || hasManagedLidCloseSleepOverride || experimentalLidCloseMode
    }

    private func restoreLidCloseModeSynchronously() {
        do {
            try lidCloseController.setSleepDisabled(false)
            defaults.set(false, forKey: DefaultsKey.managedLidCloseSleepOverride)
        } catch {
            lastError = "应用退出时未能恢复盒盖睡眠设置：\(error.localizedDescription)"
        }
    }

    private func recoverLingeringLidCloseOverrideIfNeeded() {
        guard hasManagedLidCloseSleepOverride || experimentalLidCloseMode else { return }

        do {
            let hadManagedOverride = hasManagedLidCloseSleepOverride
            let isSleepDisabled = try lidCloseController.isSleepDisabled()

            guard isSleepDisabled || hadManagedOverride else {
                return
            }

            if isSleepDisabled {
                try lidCloseController.setSleepDisabled(false)
            }

            defaults.set(false, forKey: DefaultsKey.managedLidCloseSleepOverride)
            refreshLidCloseStatusText()
        } catch {
            lidCloseStatusText = "发现上次遗留设置"
            lastError = "检测到上次会话未恢复盒盖睡眠设置：\(error.localizedDescription)"
        }
    }

    private func applySystemPowerSnapshot(_ snapshot: PowerSettingsSnapshot) {
        switch snapshot.sleepDisabled {
        case .some(true):
            systemPowerStatusText = "合盖不睡眠已生效"
            systemPowerStatusDetailText = "现在合盖可能不会睡眠。任务结束后会尝试恢复，也可以手动恢复。"
            canRestoreSystemSleep = true
        case .some(false):
            systemPowerStatusText = "合盖会正常睡眠"
            systemPowerStatusDetailText = "未检测到合盖不睡眠设置。"
            canRestoreSystemSleep = false
        case .none:
            if snapshot.idleSleepMinutes == 0 {
                systemPowerStatusText = "自动睡眠已关闭"
                systemPowerStatusDetailText = "未读到合盖开关，但系统当前不会自动睡眠。"
            } else {
                systemPowerStatusText = "未读到合盖设置"
                systemPowerStatusDetailText = "没有读到系统里的合盖睡眠开关。"
            }
            canRestoreSystemSleep = false
        }

        if snapshot.sleepDisabled != true, snapshot.idleSleepMinutes == 0 {
            systemPowerStatusDetailText = "合盖睡眠未被禁用，但自动睡眠当前是关闭的。"
        }

        systemPowerStatusUpdatedText = "检查于 \(Self.statusTimeFormatter.string(from: snapshot.capturedAt))"
    }

    private func refreshLidCloseStatusText(systemSleepAlreadyDisabled: Bool = false) {
        guard isActive else {
            lidCloseStatusText = "未开启"
            return
        }

        guard experimentalLidCloseMode else {
            lidCloseStatusText = "未开启"
            return
        }

        lidCloseStatusText = systemSleepAlreadyDisabled ? "已开启（原本已生效）" : "已开启"
    }

    private func refreshBatterySnapshot() {
        currentBatterySnapshot = readBatterySnapshot()

        guard currentBatterySnapshot.isAvailable else {
            batteryStatusText = "当前设备未检测到内置电池"
            return
        }

        guard let percentage = currentBatterySnapshot.percentage else {
            batteryStatusText = "无法读取当前电量"
            return
        }

        if currentBatterySnapshot.isCharging {
            batteryStatusText = "当前电量 \(percentage)% ，正在充电"
        } else if currentBatterySnapshot.isOnBattery {
            batteryStatusText = "当前电量 \(percentage)% ，使用电池供电"
        } else {
            batteryStatusText = "当前电量 \(percentage)%"
        }
    }

    private func evaluateBatteryProtection() {
        guard isActive else { return }
        guard shouldStopForLowBattery(currentBatterySnapshot) else { return }

        if let percentage = currentBatterySnapshot.percentage {
            stopSession(reason: "当前电量降到 \(percentage)% ，已自动关闭防休眠。")
        } else {
            stopSession(reason: "电量状态不适合继续保持防休眠，已自动关闭。")
        }
    }

    private func shouldStopForLowBattery(_ snapshot: BatterySnapshot) -> Bool {
        guard lowBatteryProtectionEnabled else { return false }
        guard snapshot.isAvailable, snapshot.isOnBattery, !snapshot.isCharging else { return false }
        guard let percentage = snapshot.percentage else { return false }
        return percentage <= lowBatteryThreshold
    }

    private func readBatterySnapshot() -> BatterySnapshot {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array

        for source in powerSources {
            guard let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let type = description[kIOPSTypeKey as String] as? String
            if let type, type != (kIOPSInternalBatteryType as String) {
                continue
            }

            let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int
            let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
            let isOnBattery = powerSourceState == (kIOPSBatteryPowerValue as String)

            let percentage: Int?
            if let currentCapacity, let maxCapacity, maxCapacity > 0 {
                percentage = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
            } else {
                percentage = currentCapacity
            }

            return BatterySnapshot(
                percentage: percentage,
                isCharging: isCharging,
                isOnBattery: isOnBattery,
                isAvailable: true
            )
        }

        return BatterySnapshot(percentage: nil, isCharging: false, isOnBattery: false, isAvailable: false)
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

    private func refreshUpdatePresentation() {
        updateStatusText = "当前版本 \(updateController.currentVersion)"
        updateDetailText = "启动后会自动检查 GitHub Release，也可以手动检查。"
        canDownloadUpdate = false
    }

    private static func defaultDeadlineDate() -> Date {
        let calendar = Calendar.current
        return calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 10, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(12 * 3600)
    }

    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private enum DefaultsKey {
    static let scheduleMode = "scheduleMode"
    static let selectedPresetMinutes = "selectedPresetMinutes"
    static let customDurationValue = "customDurationValue"
    static let customDurationUnit = "customDurationUnit"
    static let deadlineDate = "deadlineDate"
    static let experimentalLidCloseMode = "experimentalLidCloseMode"
    static let lowBatteryProtectionEnabled = "lowBatteryProtectionEnabled"
    static let lowBatteryThreshold = "lowBatteryThreshold"
    static let managedLidCloseSleepOverride = "managedLidCloseSleepOverride"
}
