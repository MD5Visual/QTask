# Build Hash System

This directory contains the build hash generation script.

## Usage

Run this before testing to generate a new build hash:

```bash
dart run tool/generate_build_hash.dart
```

The hash will be displayed in the app bar on the home screen as a small chip (e.g., "55BE29").

## What it does

1. Generates SHA-256 hashes of critical source files
2. Combines them into a single build hash
3. Creates `lib/generated/build_info.dart` with the hash and timestamp
4. The home screen displays the short hash (first 6 characters)

## When to regenerate

- After making code changes you want to verify are loaded
- Before testing to ensure you're running the latest code
- When hot reload doesn't seem to be picking up changes

## Tooltip

Hover over the hash chip in the app to see:
- Full build hash (12 characters)
- Build timestamp

This helps verify that code changes have been loaded, especially when hot reload might miss certain changes (like provider updates).
