import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var store: AgentDutyStore?

    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.store?.prepareForTermination()
    }
}

@main
struct StayAwakeForAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AgentDutyStore()

    init() {
        AppDelegate.store = _store.wrappedValue
    }

    var body: some Scene {
        WindowGroup(AppIdentity.productName, id: AppIdentity.mainWindowID) {
            MainWindowView(store: store)
        }
        .defaultSize(width: 560, height: 760)

        MenuBarExtra {
            AgentControlView(store: store, presentation: .menuBar)
        } label: {
            Label(store.menuBarTitle, systemImage: store.isActive ? "bolt.fill" : "bolt.slash")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MainWindowView: View {
    @ObservedObject var store: AgentDutyStore

    var body: some View {
        AgentControlView(store: store, presentation: .window)
            .frame(minWidth: 520, minHeight: 720)
    }
}

private enum ControlPresentation {
    case window
    case menuBar
}

private struct AgentControlView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var store: AgentDutyStore
    let presentation: ControlPresentation

    private let presetColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        Group {
            if presentation == .window {
                ScrollView {
                    content
                        .padding(20)
                }
                .background(Color(NSColor.windowBackgroundColor))
            } else {
                content
                    .padding(16)
                    .frame(width: 380)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if presentation == .window {
                heroSection
            }
            activationControl
            statusSection
            scheduleSection
            lidCloseSection
            batteryProtectionSection
            launchAtLoginSection
            

            if let lastError = store.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if presentation == .menuBar {
                Divider()

                HStack {
                    Button("打开主窗口") {
                        openWindow(id: AppIdentity.mainWindowID)
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    Spacer()

                    Button("退出") {
                        store.prepareForTermination()
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentity.productName)
                    .font(presentation == .window ? .title2.weight(.semibold) : .title3.weight(.semibold))
                Text(store.isActive ? "让 Agent 持续在线工作" : "先配置，再一键开始")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.isActive ? "运行中" : "待命中")
                .font(.caption.weight(.semibold))
                .foregroundStyle(store.isActive ? .green : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(store.isActive ? Color.green.opacity(0.14) : Color.secondary.opacity(0.12))
                )
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            HeroBannerImage()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.34),
                            Color.black.opacity(0.62),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 12) {
                Text(store.isActive ? "保持 Agent 在线值守" : "给长任务一个稳定夜班")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                Text("适合 Loom、自动化任务、长时生成和远程处理场景。")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.82))

                HStack(spacing: 8) {
                    bannerChip(text: store.isActive ? "防休眠进行中" : "等待启动", tint: store.isActive ? Color.green : Color.accentColor)
                    bannerChip(text: store.scheduleMode.title, tint: Color.cyan)
                    if store.lowBatteryProtectionEnabled {
                        bannerChip(text: "低电量保护", tint: Color.orange)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        if store.isActive {
                            store.stopSession(reason: nil)
                        } else {
                            store.startSession()
                        }
                    } label: {
                        Label(store.isActive ? "停止防休眠" : "立即开始", systemImage: store.isActive ? "pause.circle.fill" : "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        store.prepareForTermination()
                        NSApp.terminate(nil)
                    } label: {
                        Label("退出软件", systemImage: "power")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(18)
        }
    }

    private var activationControl: some View {
        SectionCard {
            settingHeader(
                title: "防休眠",
                detail: store.subtitleText,
                toggle: store.toggleBinding
            )
        }
    }

    private var statusSection: some View {
        SectionCard(title: "状态") {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.countdownText)
                    .font(.system(size: presentation == .window ? 32 : 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(store.statusHintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
    }

    private var scheduleSection: some View {
        SectionCard(
            title: "时间计划",
            detail: "选择保持唤醒的方式。默认使用无限模式。"
        ) {
            SegmentedControl(
                segments: SessionScheduleMode.allCases.map { .init(id: $0.id, title: $0.title) },
                selectionID: store.scheduleMode.id,
                isDisabled: store.isActive
            ) { selectedID in
                guard let mode = SessionScheduleMode.allCases.first(where: { $0.id == selectedID }) else { return }
                store.setScheduleMode(mode)
            }

            switch store.scheduleMode {
            case .infinite:
                infoBlock(text: "默认模式。开启后会一直保持唤醒，直到你主动关闭。")
            case .preset:
                LazyVGrid(columns: presetColumns, spacing: 10) {
                    ForEach(store.presetOptions) { preset in
                        Button {
                            store.selectPreset(preset.minutes)
                        } label: {
                            Text(preset.title)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(store.selectedPresetMinutes == preset.minutes ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .disabled(store.isActive)
            case .custom:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        TextField("输入时长", text: Binding(
                            get: { store.customDurationText },
                            set: { store.setCustomDurationText($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .disabled(store.isActive)

                        SegmentedControl(
                            segments: DurationUnit.allCases.map { .init(id: $0.id, title: $0.title) },
                            selectionID: store.customDurationUnit.id,
                            isDisabled: store.isActive,
                            compact: true
                        ) { selectedID in
                            guard let unit = DurationUnit.allCases.first(where: { $0.id == selectedID }) else { return }
                            store.setCustomDurationUnit(unit)
                        }
                    }

                    Text(store.customDurationValidationMessage ?? "你可以输入任意分钟数，或切换成小时。")
                        .font(.caption)
                        .foregroundColor(store.customDurationValidationMessage == nil ? .secondary : .red)
                }
            case .deadline:
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "结束时间",
                        selection: Binding(
                            get: { store.deadlineDate },
                            set: { store.setDeadlineDate($0) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .disabled(store.isActive)

                    Text("适合“直到明天早上 10:00”或“直到明晚 22:00”这种固定截止时间。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var batteryProtectionSection: some View {
        SectionCard {
            settingHeader(
                title: "低电量保护",
                detail: "电量低于阈值时，自动关闭防休眠，避免任务把电池拖空。",
                toggle: Binding(
                    get: { store.lowBatteryProtectionEnabled },
                    set: { store.setLowBatteryProtectionEnabled($0) }
                )
            )

            metricRow(label: "保护阈值", value: "\(store.lowBatteryThreshold)%")

            Stepper(
                value: Binding(
                    get: { store.lowBatteryThreshold },
                    set: { store.setLowBatteryThreshold($0) }
                ),
                in: 5...50,
                step: 5
            ) {
                Text("以 5% 为步进调整阈值")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!store.lowBatteryProtectionEnabled)

            // metricRow(label: "当前电量", value: store.batteryStatusText)
        }
    }

    private var launchAtLoginSection: some View {
        SectionCard {
            settingHeader(
                title: "开机自启",
                detail: "登录 macOS 后自动启动，适合长期运行 Agent。",
                toggle: Binding(
                    get: { store.launchAtLoginEnabled },
                    set: { store.setLaunchAtLogin($0) }
                )
            )

            metricRow(label: "登录项状态", value: store.launchAtLoginStatusText)

            if store.canShowLoginSettingsShortcut {
                Button("打开登录项设置") {
                    store.openLoginItemsSettings()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var lidCloseSection: some View {
        SectionCard {
            settingHeader(
                title: "合盖不睡眠（实验）",
                detail: "让 MacBook 合盖后也尽量继续运行；需要管理员授权。",
                toggle: Binding(
                    get: { store.experimentalLidCloseMode },
                    set: { store.setExperimentalLidCloseMode($0) }
                ),
                disabled: !store.isActive
            )

            metricRow(label: "本次会话", value: store.lidCloseStatusText)
            metricRow(label: "系统设置", value: store.systemPowerStatusText)

            Text(store.systemPowerStatusDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    store.refreshSystemPowerStatus()
                } label: {
                    Label(store.isRefreshingSystemPowerStatus ? "检查中" : "重新检查", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.isRefreshingSystemPowerStatus)

                Button(role: .destructive) {
                    store.restoreSystemSleepNow()
                } label: {
                    Label("恢复合盖睡眠", systemImage: "bed.double")
                }
                .buttonStyle(.bordered)
                .disabled(store.isRefreshingSystemPowerStatus || !store.canRestoreSystemSleep)

                Spacer()
            }

            if !store.systemPowerStatusUpdatedText.isEmpty {
                Text(store.systemPowerStatusUpdatedText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoBlock(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
    }

    private func settingHeader(
        title: String,
        detail: String,
        toggle: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.headline)
                Spacer(minLength: 16)
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .fixedSize()
                    .disabled(disabled)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.top, 2)
    }

    private func bannerChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.32))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
    }
}

private struct SectionCard<Content: View>: View {
    let title: String?
    let detail: String?
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SegmentItem: Identifiable {
    let id: String
    let title: String
}

private struct SegmentedControl: View {
    let segments: [SegmentItem]
    let selectionID: String
    let isDisabled: Bool
    var compact = false
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(segments) { segment in
                Button {
                    onSelect(segment.id)
                } label: {
                    Text(segment.title)
                        .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundColor(selectionID == segment.id ? Color.white : Color.white.opacity(0.78))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 8 : 10)
                        .padding(.horizontal, compact ? 10 : 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectionID == segment.id ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectionID == segment.id ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.6 : 1)
    }
}

private struct HeroBannerImage: View {
    var body: some View {
        if let image = loadImage() {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.13, blue: 0.20), Color(red: 0.05, green: 0.26, blue: 0.31)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func loadImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "HeroBanner", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
