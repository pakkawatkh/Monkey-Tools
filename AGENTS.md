# AGENTS.md — Monkey Tools Development & Release Guide

> Repository-level playbook for AI coding agents working on **Monkey Tools** (`https://github.com/pakkawatkh/monkey-tools`). Follow these rules and release steps consistently in every session.

---

## 1. Project Overview

- **App Name:** `Monkey Tools` (`monkey-tools.app`)
- **Bundle Identifier:** `com.local.monkey-tools` *(never change — preserves macOS Accessibility TCC permissions and user data)*
- **Platform:** Native macOS 13.0+ (Apple Silicon & Intel), Swift 5.9+, SwiftUI, AppKit, Vision (Offline OCR), Carbon (`RegisterEventHotKey`), CoreGraphics (`CGEvent`)
- **License:** Open Source — MIT License
- **Release Portal:** `../Pliw-App/monkey-tools/` → Live at `https://pakkawatkh.github.io/Pliw-App/monkey-tools/`
- **Auto-Update Manifest:** `https://pakkawatkh.github.io/Pliw-App/monkey-tools/version.json`

### Core Features
1. **Clipboard History (`⌘⇧V` / `⌥V`):** Text, code, URLs, passwords, and images with source app icons, category filters (`All`, `Text`, `Images`, `Pinned`), quick paste (`⌘1`–`⌘9`), Pin (`⌘P`), Delete (`⌘⌫`), Quick Preview (`⌘Y`), Translate (`⌘T`), offline Apple Vision OCR, Pause/Resume, and per-app exclusions.
2. **Continuous Emoji Picker:** Multi-insert emoji picker with search.
3. **Smart Selection Translator & Quick Translate (`⌘⇧E`):** Floating selection bubble + instant translate popup with 3-tier Google Translate fallback, Apple Native dictionary, TTS, Replace In-Place, translation history, and per-app exclusions.
4. **Live Menu Bar Network Speed:** Kernel-counter (`getifaddrs`) download/upload monitor.
5. **One-Click In-App Auto-Updater:** Checks `version.json`, downloads `monkey-tools.zip`, strips quarantine, replaces `/Applications/monkey-tools.app`, and relaunches automatically.

---

## 2. Mandatory Rules

1. **Never filter passwords from Clipboard History:** Do **not** skip `ConcealedType` or `TransientType` pasteboard entries; users explicitly expect passwords to be recorded.
2. **Preserve macOS Accessibility TCC permissions:** Always sign release builds in `scripts/build_app.sh` using the persistent self-signed certificate (`MonkeyToolsDeveloper` / `MonkeyCopyDeveloper`). Never remove or downgrade this signing step.
3. **Multi-language UI:** Maintain full localization support (`th`, `en`, `zh`) for all user-facing strings.
4. **Keep the One-Click Auto-Updater working:** Always keep `UpdateCheckService.primaryManifestURL` pointing to `https://pakkawatkh.github.io/Pliw-App/monkey-tools/version.json`.
5. **Use relative paths in scripts:** Never hardcode machine-specific absolute paths in build or packaging scripts.

---

## 3. Standard End-to-End Release Workflow

Never stop after editing code. Complete every step below in one pass:

1. **Run all unit tests:**
   ```bash
   swift test
   ```
   All tests must pass with zero failures.
2. **Bump version** in `scripts/build_app.sh` (`CFBundleShortVersionString` and `CFBundleVersion`).
3. **Build, sign, install, and package:**
   ```bash
   ./scripts/create_dmg.sh
   ```
   This builds Release `monkey-tools.app`, signs it, updates `/Applications/monkey-tools.app`, creates `monkey-tools-Installer.dmg` + `monkey-tools.zip`, and syncs them to `../Pliw-App/monkey-tools/`.
4. **Update Release Portal (`../Pliw-App`):**
   - Update `../Pliw-App/monkey-tools/version.json` (`latestVersion`, `releaseDate`, `releaseNotes`).
   - Update version and exact DMG size in `../Pliw-App/index.html`, `../Pliw-App/monkey-tools/index.html`, `../Pliw-App/README.md`, and `./README.md`.
   - Follow `../Pliw-App/AGENTS.md` (100% English, minimal copy, no keyboard shortcuts in descriptions).
5. **Commit & push both repositories:**
   ```bash
   git add -A && git commit -m "chore: release vX.Y.Z - <summary>" && git push origin main
   cd ../Pliw-App && git add -A && git commit -m "chore(release): Monkey Tools vX.Y.Z" && git push origin main
   ```
