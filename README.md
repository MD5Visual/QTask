# QTask

A clean, modern task management application built with Flutter that stores tasks in Markdown format. Features a rich text editor with drag-and-drop image support for task descriptions.

## ✨ Features

- **Markdown Storage**: All tasks saved as plain Markdown files for portability and version control
- **Rich Text Editor**: WYSIWYG editor powered by flutter_quill with full formatting support
- **Drag & Drop Images**: Easily add images to task descriptions via drag and drop
- **Task Lists**: Organize tasks into custom lists
- **Cross-Platform**: Runs on Windows, macOS, and Android
- **Dark Mode**: Built-in dark mode support
- **Clean UI**: Modern, intuitive interface

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.2.0 or higher)
- For Windows: Visual Studio 2022 with C++ desktop development
- For macOS: Xcode 14 or higher
- For Android: Android Studio with Android SDK

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/qtask.git
cd qtask
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

## 📁 Data Storage

QTask stores data in the following directories:

- **Tasks**: `tasks/` - Individual task Markdown files
- **Task Lists**: `task_lists/` - List configuration files
- **Attachments**: `task_attachments/` - Images and files attached to tasks

## 🛠️ Technology Stack

- **Framework**: Flutter
- **Language**: Dart
- **Rich Text**: flutter_quill, markdown_quill
- **Drag & Drop**: desktop_drop
- **State Management**: Provider
- **Storage**: Local file system (Markdown)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📮 Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/yourusername/qtask/issues) page.

---

**Version**: 0.7.1
