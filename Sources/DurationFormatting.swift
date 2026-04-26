import Foundation

func formatDuration(_ totalSeconds: Int) -> String {
    let clamped = max(totalSeconds, 0)
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60
    let seconds = clamped % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

func formatMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return "\(hours) 小时"
        }

        return "\(hours) 小时 \(remainingMinutes) 分钟"
    }

    return "\(minutes) 分钟"
}
