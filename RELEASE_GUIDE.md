# QTask Release Guide

This guide explains how to create releases for QTask on GitHub, both manually and using automated workflows.

## Table of Contents

- [Automated Releases (Recommended)](#automated-releases-recommended)
- [Manual Releases](#manual-releases)
- [Version Numbering](#version-numbering)
- [Release Checklist](#release-checklist)

## Automated Releases (Recommended)

QTask uses GitHub Actions to automatically build and release for multiple platforms when you push a version tag.

### Steps

1. **Update the version** in your code:
   ```bash
   # Update version in pubspec.yaml (e.g., 0.7.1+1 -> 0.8.0+1)
   # Update version in lib/main.dart (e.g., 'QTask v0.7.1' -> 'QTask v0.8.0')
   ```

2. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Bump version to 0.8.0"
   ```

3. **Create and push a version tag**:
   ```bash
   git tag v0.8.0
   git push origin main
   git push origin v0.8.0
   ```

4. **Wait for the workflow to complete**:
   - Go to your repository's "Actions" tab on GitHub
   - Watch the "Release Build" workflow run
   - It will build for Windows, macOS (Apple Silicon), and Android
   - A new release will be created automatically with all artifacts

### What Gets Built

The automated workflow builds:
- **Windows**: `qtask-windows-x64.zip` - Contains the Windows executable and dependencies
- **macOS**: `qtask-macos-arm64.zip` - Contains the macOS app bundle for Apple Silicon
- **Android**: `app-release.apk` - Android APK file

## Manual Releases

If you prefer to create releases manually or the automated workflow isn't suitable:

### 1. Build for Each Platform

#### Windows
```bash
flutter build windows --release
cd build/windows/x64/runner/Release
# Zip the contents
```

#### macOS (Apple Silicon)
```bash
flutter build macos --release
cd build/macos/Build/Products/Release
zip -r qtask-macos-arm64.zip qtask.app
```

#### Android
```bash
flutter build apk --release
# APK will be in build/app/outputs/flutter-apk/app-release.apk
```

### 2. Create GitHub Release

1. Go to your repository on GitHub
2. Click "Releases" → "Draft a new release"
3. Create a new tag (e.g., `v0.8.0`)
4. Set the release title (e.g., "QTask v0.8.0")
5. Write release notes describing changes
6. Upload the built artifacts:
   - Windows ZIP file
   - macOS ZIP file
   - Android APK file
7. Click "Publish release"

## Version Numbering

QTask follows semantic versioning: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes or major feature overhauls
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible
- **BUILD**: Build number (increment for each build)

### Examples

- `0.7.1+1` → `0.7.2+1` - Bug fix
- `0.7.1+1` → `0.8.0+1` - New feature
- `0.7.1+1` → `1.0.0+1` - Major release

## Release Checklist

Before creating a release:

- [ ] All tests pass (`flutter test`)
- [ ] Code is properly formatted (`flutter format .`)
- [ ] No lint errors (`flutter analyze`)
- [ ] Version updated in `pubspec.yaml`
- [ ] Version updated in `lib/main.dart`
- [ ] CHANGELOG updated (if you maintain one)
- [ ] All changes committed to main branch
- [ ] Tested on target platforms

## Troubleshooting

### Workflow Fails on macOS Build

macOS builds require a macOS runner. GitHub provides macOS runners, but they may have limitations:
- Ensure you're using `macos-14` for Apple Silicon builds
- Check that your Flutter version is compatible

### Android Build Fails

Common issues:
- Java version mismatch (workflow uses Java 17)
- Missing Android SDK components
- Gradle configuration issues

### Windows Build Fails

Common issues:
- Missing Visual Studio components
- Flutter version compatibility
- Path length limitations on Windows

## Additional Resources

- [Flutter Build Documentation](https://docs.flutter.dev/deployment)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Semantic Versioning](https://semver.org/)

---

For questions or issues, please open an issue on GitHub.
