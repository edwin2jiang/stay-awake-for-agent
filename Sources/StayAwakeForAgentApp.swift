import AppKit
import SwiftUI

@main
struct StayAwakeForAgentApp: App {
    @StateObject private var store = AgentDutyStore()

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
            activationControl
            statusSection
            scheduleSection
            batteryProtectionSection
            launchAtLoginSection
            lidCloseSection

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

    private var activationControl: some View {
        Toggle(isOn: store.toggleBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Text("防休眠")
                    .font(.headline)
                Text(store.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态")
                .font(.headline)

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
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间计划")
                .font(.headline)

            Picker("时间计划", selection: Binding(
                get: { store.scheduleMode },
                set: { store.setScheduleMode($0) }
            )) {
                ForEach(SessionScheduleMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.isActive)

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

                        Picker("单位", selection: Binding(
                            get: { store.customDurationUnit },
                            set: { store.setCustomDurationUnit($0) }
                        )) {
                            ForEach(DurationUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(store.isActive)
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
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.lowBatteryProtectionEnabled },
                set: { store.setLowBatteryProtectionEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("低电量保护")
                        .font(.headline)
                    Text("电量低于阈值时，自动关闭防休眠，避免任务把电池拖空。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            HStack {
                Text("保护阈值")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.lowBatteryThreshold)%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

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

            Text(store.batteryStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.launchAtLoginEnabled },
                set: { store.setLaunchAtLogin($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开机自启")
                        .font(.headline)
                    Text("登录 macOS 后自动启动，适合长期运行 Agent。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            HStack {
                Text("登录项状态")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.launchAtLoginStatusText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

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
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.experimentalLidCloseMode },
                set: { store.setExperimentalLidCloseMode($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实验性盒盖模式")
                        .font(.headline)
                    Text("需要管理员授权；依赖系统行为，不保证所有机型都稳定。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(store.isActive)

            HStack {
                Text("盒盖状态")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.lidCloseStatusText)
                    .font(.caption.monospacedDigit())
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
}
