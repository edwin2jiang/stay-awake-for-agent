# Stay Awake for Agent

[English](README.md) | [中文](README.zh-CN.md)

Stay Awake for Agent is a small macOS menu bar app for long-running agent workflows. It keeps your Mac awake while automation, uploads, recordings, or remote jobs are still running, with clear controls for duration, battery protection, launch at login, and an experimental lid-close mode.

The default stay-awake behavior uses Apple's public IOKit power assertion API. The lid-close behavior is marked experimental because macOS does not provide a stable public API for preventing sleep caused by closing a laptop lid.

## Features

- Menu bar and regular window controls
- Infinite mode by default
- Presets: 15 minutes, 30 minutes, 1 hour, 2 hours, 3 hours, 6 hours
- Custom duration in minutes or hours
- Deadline mode for a specific date and time
- Live countdown
- Low-battery protection with a configurable threshold
- Launch at login
- Experimental lid-close mode
- App icon and bundled release packaging scripts

## Download

For normal users, download the latest prebuilt archive from GitHub Releases:

1. Open the repository's **Releases** page.
2. Download `Stay-Awake-for-Agent-macOS-<version>.zip`.
3. Unzip it.
4. Move `Stay Awake for Agent.app` to `/Applications`.
5. Open it from Finder once so macOS can show any security prompt.

If macOS says the app cannot be opened because the developer cannot be verified, open **System Settings > Privacy & Security**, scroll to the security message for Stay Awake for Agent, and choose **Open Anyway**. This is expected for unsigned local builds.

## First Run

After launching the app:

1. Use the main **Stay Awake** switch to start or stop an awake session.
2. Pick a duration mode before starting if you do not want infinite mode.
3. Enable **Low Battery Protection** if you are running on a laptop battery.
4. Use **Launch at Login** only if you want the app to start automatically after signing in.
5. Use **Experimental Lid-Close Mode** only when you understand the extra system-level change described below.

The app stays available from the macOS menu bar while it is running.

## Permissions and macOS Security

### Standard Stay-Awake Mode

The normal stay-awake mode does not need administrator permission. It creates a `NoIdleSleep` power assertion through `IOPMAssertionCreateWithName`, and releases that assertion when the session stops or the app quits.

### Experimental Lid-Close Mode

Closing a MacBook lid normally requests sleep. Apple's public power assertion APIs do not reliably override that lid-close sleep path, so this app uses:

```bash
pmset -a disablesleep 1
```

macOS requires administrator authorization for that command. When the session stops, the app restores the default behavior with:

```bash
pmset -a disablesleep 0
```

If your Mac ever remains stuck in a no-lid-sleep state, run:

```bash
sudo pmset -a disablesleep 0
```

You can inspect the current state with:

```bash
pmset -g
pmset -g assertions
```

## Build from Source

Requirements:

- macOS 13 or later
- Xcode Command Line Tools
- Swift Package Manager

Build the app bundle:

```bash
swift build
./Scripts/build-app.sh
```

The app bundle is written to:

```bash
./dist/Stay Awake for Agent.app
```

Run it:

```bash
open "./dist/Stay Awake for Agent.app"
```

For development, restart the app with:

```bash
./Scripts/restart-app.sh
```

## Create a Release Package

To build a zip archive for GitHub Releases:

```bash
./Scripts/package-release.sh
```

This creates files under `dist/release/`, including:

- `Stay-Awake-for-Agent-macOS-<version>.zip`
- `Stay-Awake-for-Agent-macOS-<version>.zip.sha256`

Upload both files to a GitHub Release. The release notes can use the template in [RELEASE.md](RELEASE.md).

## Technical Notes

The stable stay-awake mode uses `IOPMAssertionCreateWithName` with `NoIdleSleep`. This prevents idle sleep while the app session is active.

The experimental lid-close mode uses `pmset disablesleep`, which is not a formally documented `pmset(1)` setting. The app treats it as a reversible session-level override and attempts to restore it when the session ends, when the experimental switch is turned off, and when the app exits.

## References

- Apple `caffeinate(8)` manual
- Apple IOKit power assertion documentation
- Apple Support closed-display mode documentation
- [Amphetamine Enhancer](https://github.com/x74353/Amphetamine-Enhancer)
- [Amphetamine notes](https://github.com/x74353/Amphetamine)
- [Fermata](https://github.com/iccir/Fermata)
- [NoSleep issue #52](https://github.com/integralpro/nosleep/issues/52)

## License

MIT
