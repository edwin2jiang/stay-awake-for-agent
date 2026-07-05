## Stay Awake for Agent {{VERSION}}

### What's Changed

- Added a built-in software update panel that checks the latest GitHub Release.
- Added one-click download for the latest universal DMG, saved to Downloads and opened automatically.
- This is a test update release so users can verify the update-check flow from inside the app.

### Download

Download `{{DMG_NAME}}` from the assets below.

This is the right download for both Apple Silicon and Intel Macs. The DMG contains a universal macOS app with `arm64` and `x86_64` slices.

### Install

1. Open `{{DMG_NAME}}`.
2. Drag `Stay Awake for Agent.app` to **Applications**.
3. Open the app from Finder once.
4. If macOS blocks the app because it is from an unidentified developer, open **System Settings > Privacy & Security** and choose **Open Anyway** for Stay Awake for Agent.

The zip file is also attached as a fallback for users who prefer archive downloads.

### Use

1. Turn on the main **Stay Awake** switch to start an awake session.
2. Pick a duration before starting if you do not want infinite mode.
3. Enable **Low Battery Protection** when running on battery.
4. Enable **Launch at Login** only if you want the app to start automatically after signing in.

### Experimental Lid-Close Mode

Standard stay-awake mode does not need administrator permission. Experimental lid-close mode does require administrator authorization because it uses `pmset` to request `disablesleep`.

If your Mac ever remains stuck in a no-lid-sleep state, run:

```bash
sudo pmset -a disablesleep 0
```

### Verify the Download

Compare the checksum file with:

```bash
shasum -a 256 "{{DMG_NAME}}"
cat SHA256SUMS.txt
```
