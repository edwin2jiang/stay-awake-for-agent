# Maintainer Release Checklist

Use this checklist when preparing a GitHub Release for Stay Awake for Agent. The GitHub Actions release workflow can create or update the Release automatically.

## Automatic Release

### From a tag

Push a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The `Release` workflow will:

- build the app bundle
- package the universal DMG and fallback zip archive
- create or update the matching GitHub Release
- upload the `.dmg`, `.zip`, and `SHA256SUMS.txt` assets
- publish user-facing install instructions from `GITHUB_RELEASE.md`

### Manually from GitHub Actions

Run the `Release` workflow from the GitHub Actions tab. Leave the tag blank to use `v<CFBundleShortVersionString>` from `Resources/Info.plist`, or provide a custom tag name.

## Local Package Test

Before publishing, you can test the package locally:

```bash
./Scripts/package-release.sh
```

The release artifacts are written to `dist/release/`:

- `Stay-Awake-for-Agent-macOS-<version>.dmg`
- `Stay-Awake-for-Agent-macOS-<version>.zip`
- `SHA256SUMS.txt`

## Checksum

Verify the download with:

```bash
shasum -a 256 "Stay-Awake-for-Agent-macOS-<version>.zip"
cat SHA256SUMS.txt
```
