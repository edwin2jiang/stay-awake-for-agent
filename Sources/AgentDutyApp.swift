import SwiftUI

@main
struct AgentDutyApp: App {
    @StateObject private var store = AgentDutyStore()

    var body: some Scene {
        MenuBarExtra {
            AgentDutyPanel(store: store)
        } label: {
            Label(store.menuBarTitle, systemImage: store.isActive ? "bolt.fill" : "bolt.slash")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct AgentDutyPanel: View {
    @ObservedObject var store: AgentDutyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            activationToggle
            modePicker

            if store.sessionMode == .timed {
                durationControl
            }

            countdownCard
            launchAtLoginControl
            lidCloseControl

            if let lastError = store.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentity.productName)
                    .font(.title3.weight(.semibold))
                Text(store.isActive ? "让 Agent 持续在线工作" : "待命中，允许系统正常休眠")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.isActive ? "运行中" : "已停止")
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

    private var activationToggle: some View {
        Toggle(isOn: store.toggleBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Text("一键防休眠")
                    .font(.headline)
                Text(store.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("模式")
                .font(.headline)

            Picker("模式", selection: Binding(
                get: { store.sessionMode },
                set: { newValue in
                    guard !store.isActive else { return }
                    store.sessionMode = newValue
                    store.persistMode()
                })
            ) {
                ForEach(SessionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.isActive)
        }
    }

    private var durationControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("时长")
                    .font(.headline)
                Spacer()
                Text(formatMinutes(store.durationMinutes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Stepper(
                value: Binding(
                    get: { store.durationMinutes },
                    set: { newValue in
                        guard !store.isActive else { return }
                        store.durationMinutes = newValue
                        store.persistDuration()
                    }),
                in: 5...720,
                step: 5
            ) {
                Text("每次增加或减少 5 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(store.isActive)
        }
    }

    private var countdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(store.countdownText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(store.sessionMode == .infinite ? "无限模式下不会自动结束" : "倒计时会在到点后自动关闭防休眠")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
    }

    private var launchAtLoginControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.launchAtLoginEnabled },
                set: { newValue in
                    store.setLaunchAtLogin(newValue)
                })
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开机自启")
                        .font(.headline)
                    Text("登录 macOS 后自动启动，适合长期跑 Agent 任务")
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

            if store.launchAtLoginStatusText == "等待系统批准" || store.launchAtLoginStatusText == "仅在打包后的 .app 中可用" {
                Button("打开登录项设置") {
                    store.openLoginItemsSettings()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var lidCloseControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.experimentalLidCloseMode },
                set: { newValue in
                    guard !store.isActive else { return }
                    store.experimentalLidCloseMode = newValue
                    store.persistLidClosePreference()
                })
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实验性盒盖模式")
                        .font(.headline)
                    Text("需要管理员授权；依赖系统行为，不保证所有机型都稳定")
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
}
