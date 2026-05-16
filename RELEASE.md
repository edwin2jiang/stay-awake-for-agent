# Release Checklist

Use this checklist when preparing a GitHub Release for Stay Awake for Agent.

## Build

```bash
./Scripts/package-release.sh
```

The release artifacts are written to `dist/release/`.

## Upload

Attach these files to the GitHub Release:

- `Stay-Awake-for-Agent-macOS-<version>.zip`
- `Stay-Awake-for-Agent-macOS-<version>.zip.sha256`

## Suggested Release Notes

```markdown
## Stay Awake for Agent <version>

### Download

Download `Stay-Awake-for-Agent-macOS-<version>.zip`, unzip it, and move `Stay Awake for Agent.app` to `/Applications`.

### First Launch

If macOS blocks the app because it is from an unidentified developer, open **System Settings > Privacy & Security** and choose **Open Anyway** for Stay Awake for Agent.

### Notes

- Standard stay-awake mode does not need administrator permission.
- Experimental lid-close mode requires administrator authorization because it uses `pmset`.
- If lid-close sleep ever remains disabled, run `sudo pmset -a disablesleep 0`.

### Checksum

Verify the download with:

```bash
shasum -a 256 "Stay-Awake-for-Agent-macOS-<version>.zip"
cat "Stay-Awake-for-Agent-macOS-<version>.zip.sha256"
```
```
