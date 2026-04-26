import SwiftUI

@main
struct StayAwakeApp: App {
    @StateObject private var store = StayAwakeStore()

    var body: some Scene {
        MenuBarExtra {
            StayAwakePanel(store: store)
        } label: {
            Label(store.menuBarTitle, systemImage: store.isActive ? "bolt.fill" : "bolt.slash")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct StayAwakePanel: View {
    @ObservedObject var store: StayAwakeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            activationToggle
            modePicker

            if store.sessionMode == .timed {
                durationControl
            }

            countdownCard
            lidCloseControl

            if let lastError = store.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("StayAwake")
                    .font(.title3.weight(.semibold))
                Text(store.isActive ? "防休眠已开启" : "系统可正常休眠")
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
