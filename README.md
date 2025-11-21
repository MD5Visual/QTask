# QTask

A clean, modern task management application built with Flutter. QTask is designed to be the fastest way to capture and organize your thoughts, keeping your data local and accessible everywhere.

## ✨ Key Features

- **⚡ Quick & Easy**: Create and maintain task lists with zero friction. Designed for speed and simplicity.
- **🗂️ Powerful Organization**: Organize your work with custom lists, drag-and-drop reordering, and smart sorting.
- **🔒 Local First**: Your data lives on your device, not in the cloud. You own your data completely.
- **🖼️ Rich Content**: Store more than just text. Drag and drop images directly into your tasks to keep everything in context.
- **📱 Cross-Platform**: A consistent, native experience on Windows, macOS, and Android.

## � Power User Features

For those who need more control, QTask includes advanced capabilities:

- **Rich Text Editor**: Full Markdown support with a WYSIWYG toolbar.
- **Custom Data Storage**: Choose exactly where your data is saved (perfect for syncing via Dropbox/iCloud/Nextcloud).
- **Import & Export**: Full backup and restore capabilities to keep your data safe.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24.0 or higher)
- For Windows: Visual Studio 2022 with C++ desktop development
- For macOS: Xcode 14 or higher
- For Android: Android Studio with Android SDK

### Installation

1. Clone the repository:
```bash
git clone https://github.com/MD5Visual/task_app.git
cd task_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Android
flutter run -d android
```

## 🔨 Building

### Windows

```bash
flutter build windows --release
```
The executable will be in `build/windows/x64/runner/Release/`

### macOS (Apple Silicon)

```bash
flutter build macos --release
```
The app bundle will be in `build/macos/Build/Products/Release/`

### Android

```bash
flutter build apk --release
```
The APK will be in `build/app/outputs/flutter-apk/`

## 📝 License

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license. See the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📮 Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/MD5Visual/task_app/issues) page.

---

**Version**: 0.9.0
