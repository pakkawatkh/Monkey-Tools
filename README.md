# 🐵 monkey-tools 📋
> **Windows-style Clipboard History (`Win + V`), Continuous Emoji Picker, Smart Selection Translator & Real-Time Network Monitor for macOS**  
> A lightweight, powerful, and privacy-conscious all-in-one productivity suite for macOS. Seamlessly unites Windows-style Clipboard History, an instant continuous Emoji Picker, a smart floating Selection Translator, and a real-time system Network Monitor into a single menu bar utility. Crafted with Swift & SwiftUI, featuring a clean, dark acrylic design that is fast, responsive, and easy on system resources.

[![Release](https://img.shields.io/badge/Release-v2.3.1-orange?style=for-the-badge&logo=github)](https://pakkawatkh.github.io/tiffy-app/monkey-tools/)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-lightgrey?style=for-the-badge&logo=apple)](https://github.com/pakkawatkh/monkey-tools)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## 📥 Download Installer (v2.3.1)

You can download the latest official `.dmg` installer directly from the Tiffy App Release Portal:

[![Download DMG](https://img.shields.io/badge/Download-monkey--tools--Installer.dmg%20(v2.3.1)-blue?style=for-the-badge&logo=apple)](https://pakkawatkh.github.io/tiffy-app/monkey-tools/monkey-tools-Installer.dmg)

👉 **Direct Links & Live Preview:**
- **[Official Website & Interactive Tour](https://pakkawatkh.github.io/tiffy-app/monkey-tools/)**
- **[Download monkey-tools-Installer.dmg (v2.3.1 · 1.3 MB)](https://pakkawatkh.github.io/tiffy-app/monkey-tools/monkey-tools-Installer.dmg)**
- **[Download monkey-tools.zip (Auto-Update Archive)](https://pakkawatkh.github.io/tiffy-app/monkey-tools/monkey-tools.zip)**

---

## 🚀 What's New (v2.3.1 Highlights)

- 🫧 **macOS Sequoia/Tahoe Liquid Glass UI:** Automatic Light & Dark Mode support, translucent popover glass with specular rim highlights, capsule controls, and a redesigned System Settings sidebar layout.
- 🗂️ **Clipboard Category Filters & Power Shortcuts:** Filter by `All`, `Text`, `Images`, `Pinned` with source app icons, quick paste `⌘1`–`⌘9`, Pin `⌘P`, Delete `⌘⌫`, Quick Preview `⌘Y`, and Translate `⌘T`.
- 🔍 **Offline Image OCR (Apple Vision):** Extract text directly from copied screenshots and images 100% locally.
- ⚡ **Quick Translate Hotkey (`⌘⇧E`) & History:** Summon the translator instantly from anywhere, browse recent translations, and exclude specific apps from the floating selection bubble.
- 🔄 **In-App Auto-Updater:** Checks `https://pakkawatkh.github.io/tiffy-app/monkey-tools/version.json` automatically.

- 🌐 **Real-time System Network Monitor:** 
  - Live download (`⬇`) and upload (`⬆`) bandwidth speed displayed directly on the macOS Menu Bar.
  - Powered by native Darwin BSD `getifaddrs` kernel counters sampling every 1 second with near-zero energy/CPU usage (< 0.1%).
  - Smooth typography with `NSFont.monospacedDigitSystemFont` eliminating horizontal width jitter.
  - Customizable in Settings: Toggle on/off, and choose speed unit between **Auto Bytes** (`B/s`, `KB/s`, `MB/s`, `GB/s`), **Bits** (`Kbps`, `Mbps`, `Gbps`), **Fixed KB/s**, or **Fixed MB/s**.
  - Dropdown menu status integration displaying real-time speed and cumulative session data transfer totals.
- 🖱️ **120Hz Native Smooth Drag-to-Move:** Re-architected translation popover drag movement using native AppKit `window.performDrag` for butter-smooth, zero-lag window dragging that stays perfectly pinned to the cursor.
- 📐 **Omni-Directional Window Resizing:** Translation popover now supports smooth resizing from all 4 borders and 4 corners natively, alongside the corner grip handle.
- ⚡ **Instant Bubble Dismissal on Any Action:** Floating translation bubble (`SelectionBubblePanel`) now automatically and immediately dismisses upon any non-translate user action:
  - Typing or pressing any key (`keyDown`, `Esc`, `Backspace`, arrows, shortcuts)
  - Clicking anywhere outside the bubble (left, right, or middle click, deselecting text)
  - Scrolling trackpad or mouse wheel (`scrollWheel`)
  - Switching applications or window deactivation
- 🌐 **3-Tier Resilient Translation Engine:** Eliminates HTTP 429 rate limit errors with Chrome extension endpoint, single-translate fallback, and automated fallback tiers.
- 🔓 **Open Source (MIT License):** Full source code is open-source under the MIT License.

---

## 🚀 Previous Version Highlights (v2.0.0-Beta)

- 🌟 **Rebranded to monkey-tools:** Renamed the entire project from `monkey-copy` to `monkey-tools`, evolving from a simple clipboard utility into a comprehensive productivity toolkit.
- 📦 **Seamless Auto-Migration:** Automatically detects and migrates existing clipboard history and data from `monkey-copy` to `monkey-tools` without data loss.
- 🌐 **Smart Selection Translator (Instant Highlight Translation):**
  - **Floating Action Bubble (🌐):** A compact, non-intrusive bubble appears near highlighted text across any macOS application.
  - **Dual Engine Architecture:**
    - 🍎 **Apple Native:** Offline local dictionary lookup with high privacy.
    - 🌐 **Google Translate:** Powered by a resilient 3-tier translation engine (`clients5` Chrome extension endpoint, `gtx` single translate, and MyMemory fallback) eliminating HTTP 429 rate limit issues.
  - **37 Major World Languages:** Grouped logically into Popular, Asia & ASEAN, Europe, and Middle East.
  - 🔊 **Text-to-Speech (TTS):** Native high-fidelity speech audio playback for both source and translated text.
  - 🔄 **Replace In-Place (Replace Original Text):** Replace highlighted text inside editable text fields, IDEs, and chat applications in a single click.
  - ↔️ **Swap Languages:** Instantly swap source and target languages.
  - 📐 **Resizable Window:** Freely resize the translation popover with automatic persistent sizing.
  - 🖥️ **Multi-Monitor & Smart Clamping:** Ensures the floating window stays strictly within screen bounds across multiple monitors.
- 🌍 **App Language Localization:** Choose UI language between **English** 🇺🇸, **Thai (ภาษาไทย)** 🇹🇭, **Simplified Chinese (简体中文)** 🇨🇳, or follow **System Default**.
- ⚡ **Performance & Binary Optimization:**
  - Binary executable size reduced by **63%** (2.3 MB ➔ 850 KB) via Swift cross-module optimization and symbol stripping.
  - App bundle size reduced by **54%** (2.8 MB ➔ 1.3 MB).
  - Compact installer DMG at only **1.1 MB**.
  - $O(1)$ static language lookups and zero-allocation deterministic emoji identifiers.

---

## 🚀 Previous Version Highlights (v1.0.0)

- 🐵 **Windows-Style Clipboard History:** Global shortcut opens a dark acrylic floating clipboard history, similar to Windows `Win + V`.
- 🖼️ **Text & Image Clipboard Support:** Captures text, code snippets, URLs, screenshots (`Cmd + Shift + 4`), web images, and files from Finder with image thumbnails.
- 😊 **Continuous Emoji Picker:** Emoji picker with real-time search. **Clicking emojis inserts them continuously without dismissing the window.**
- ⚡ **Auto-Paste:** Automatically pastes selected clips or emojis into the active application.
- 🔒 **Persistent Code Signing:** Self-contained developer certificate prevents macOS Accessibility permissions from resetting across reboots.
- 🌙 **Clean High-Contrast Dark Theme:** Modern frosted dark glass UI with crisp readability.
- 🗑️ **Minimalist Clean Action:** Clear unpinned history with one click while keeping pinned favorites intact.
- ⌨️ **Customizable Hotkeys:** Switch between `Cmd + Shift + V`, `Option + V`, or record your own combination.

---

## ✨ Key Features

- 🌐 **Selection Translator:** Highlight text in web browsers, PDFs, code editors, or chat apps to trigger instant translations across 37 world languages.
- 🔄 **Replace In-Place:** Translate foreign text or draft replies and replace selected text immediately. Ideal for multilingual chats, customer support, and email drafting.
- 🔊 **Text-to-Speech:** Listen to native pronunciation for source and translated text.
- 🌍 **Multi-Language Interface:** Available in English, Thai, Simplified Chinese, or System Default.
- ⌨️ **Global Shortcut:** Summon clipboard history anywhere (default `Command + Shift + V` or `Option + V`).
- 📝 **Automatic Clipboard Tracking:** Constantly saves clipboard entries with real-time instant search.
- 🖼️ **Image Clipboard:** Caches screenshots and images to disk with fast image thumbnails.
- 😊 **Continuous Emoji Insertion:** Search emojis and insert multiple emojis sequentially without reopening the picker.
- 📌 **Pinning Support:** Pin frequently used clips and templates to keep them permanently at the top.
- 🐵 **Adaptive Menu Bar Icon:** High-resolution monkey glyph that automatically adapts to macOS Light/Dark mode.

---

## 🚀 Installation Guide

1. **Download the Installer:**  
   Download **`monkey-tools-Installer.dmg`** from the link above.
2. **Open the DMG:**  
   Double-click the downloaded `monkey-tools-Installer.dmg` file.
3. **Install to Applications:**  
   Drag the **monkey-tools** icon into the **Applications** folder shortcut.
4. **Launch the App:**  
   Open **monkey-tools** from your Applications folder, Spotlight (`Cmd + Space` then type `monkey-tools`), or Launchpad.

### 🛡️ First-Time Launch & macOS Gatekeeper Notice (คำแนะนำเรื่องความปลอดภัย)

When launching monkey-tools for the first time on a new Mac, macOS Gatekeeper may show a warning:  
> *"“monkey-tools” cannot be opened because Apple cannot check it for malicious software"* or *"developer cannot be verified"*

**ทำไมถึงขึ้นเตือน?**  
monkey-tools เป็นซอฟต์แวร์พัฒนาอิสระที่ไม่ได้สมัคร Apple Developer Program แบบเสียค่าบริการรายปี ($99/ปี) ทำให้ macOS ที่มีระบบ Gatekeeper แจ้งเตือนเมื่อเปิดไฟล์ที่โหลดมาจากอินเทอร์เน็ต ทั้งนี้ตัวแอปเป็นแบบ Standalone ออฟไลน์ 100% ไม่มีการส่งข้อมูลใด ๆ ออกนอกเครื่อง และปลอดภัยต่อระบบ

**วิธีเปิดใช้งาน (เลือกวิธีใดวิธีหนึ่ง):**

- **วิธีที่ 1: ผ่าน System Settings (แนะนำ - สะดวกที่สุด ไม่ต้องพิมพ์คำสั่ง)**
  1. ดับเบิลคลิกเปิด `monkey-tools.app` ครั้งแรก (จะมีหน้าต่างเตือน ให้กด **Done** หรือ **Cancel**)
  2. ไปที่ **System Settings** (การตั้งค่าระบบ) > **Privacy & Security** (ความเป็นส่วนตัวและความปลอดภัย)
  3. เลื่อนลงมาที่หัวข้อ **Security** ด้านล่าง จะพบข้อความ *"“monkey-tools” was blocked from use because it is not from an identified developer"*
  4. คลิกปุ่ม **"Open Anyway"** (เปิดต่อไป) แล้วยืนยันรหัสผ่านเครื่องหรือ Touch ID
  *(วิธีนี้จะอนุญาตเฉพาะแอป monkey-tools ตัวเดียวเท่านั้น ไม่ส่งผลกระทบต่อระบบความปลอดภัยของแอปอื่นในเครื่อง)*

- **วิธีที่ 2: ผ่าน Terminal (รวดเร็วเพียง 1 บรรทัด)**
  เปิด Terminal แล้วรันคำสั่ง:
  ```bash
  xattr -cr /Applications/monkey-tools.app
  ```
  *(เป็นการลบแท็ก Quarantine ที่ติดมาจากการดาวน์โหลดผ่านเว็บออกจากตัวแอป monkey-tools)*

---

## 🔒 Accessibility Permission Setup

To enable auto-pasting (`Cmd + V`), text selection detection, and in-place replacement:

1. Open **System Settings** on your Mac.
2. Navigate to **Privacy & Security** > **Accessibility**.
3. Toggle the switch next to **monkey-tools** to **ON (Blue)**.  
   *(If monkey-tools is not listed, click the `+` icon and select monkey-tools from your Applications folder).*

> [!TIP]
> This is a one-time setup. Thanks to monkey-tools' persistent code signing, permissions remain intact even across macOS restarts.

---

## 📖 How to Use

### 1. Clipboard History
- **Copy anything:** Use `Cmd + C` to copy text, links, code, or images normally.
- **Open history:** Press **`Command + Shift + V`** (or click the monkey icon 🐵 in the Menu Bar).
- **Paste item:**
  - Use **Arrow keys (`↑` / `↓`)** and press **`Enter`**.
  - Or **click** an item with your mouse.
  - The item will be pasted directly into your active app, and the window closes automatically.
- **Search history:** Type keywords in the top search box to filter entries in real time.
- **Pin item:** Hover over an entry and click the pin icon 📌 to keep it at the top.

---

### 2. Emoji Picker (Continuous Typing)
- Open monkey-tools and click the **`[ 😊 Emoji ]`** tab at the top.
- **Search emojis:** Type keywords in English or Thai (e.g., `monkey`, `heart`, `fire`, `smile`).
- **Insert emoji:** Click any emoji to paste it into your active document.
- **Continuous typing:** **The window remains open when selecting emojis**, allowing you to insert multiple emojis in sequence (e.g., `🐵🍌✨🔥`).
- **Dismiss picker:** Press **`Esc`**, click the **`✕`** close button, or click outside the window.

---

### 3. Selection Translator
- **Select text:** Highlight any word or sentence in a browser, PDF, chat app, or code editor.
- **Trigger translation:** A floating globe icon **🌐** appears near your selection. Click it to open the translation popover.
- **Features in translation popover:**
  - 🔄 **Engine Toggle:** Click the Google / Apple icon in the header to switch between translation engines.
  - ↔️ **Swap Languages:** Click the middle swap button to reverse source and target languages.
  - 🔊 **Listen:** Click the speaker icon to hear pronunciation.
  - 📋 **Copy:** Copy translated text to your clipboard.
  - ✍️ **Replace:** If selected text is in an editable input (text box, editor, chat input), click **"Replace"** to overwrite original text with the translation.
  - 📐 **Resize:** Drag the bottom-right grip to resize the window freely. Dimensions are remembered automatically.

---

### 4. Changing App Language
You can change the UI language across all monkey-tools windows and menus:
1. Open **Settings** (click ⚙️ in monkey-tools or right-click the Menu Bar icon > Settings).
2. Go to the **General** tab.
3. Under **App Language**, choose:
   - 🇺🇸 **English**
   - 🇹🇭 **ไทย (Thai)**
   - 🇨🇳 **中文 (Simplified Chinese)**
   - 🌐 **System Default**

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Description |
| :--- | :--- |
| **`Cmd + Shift + V`** *(Customizable)* | Toggle monkey-tools clipboard & emoji window |
| **`↑` / `↓`** | Navigate through clipboard history items |
| **`Enter`** | Paste selected item into active application |
| **`Esc`** | Close clipboard panel / translation popover |
| **Type characters** | Instantly search clipboard history or emoji catalog |

---

## ⚙️ Preferences & Customization

Open Settings in two ways:
1. Click the gear icon **⚙️** in the top-right corner of the monkey-tools window.
2. Or click the monkey icon 🐵 in the Menu Bar and select **Settings...** (or press `Cmd + ,`).

### Available Options:
- 🌍 **App Language:** Choose UI language (English, Thai, Chinese, System Default).
- 🌐 **Selection Translator:** Enable/disable floating bubble, choose default engine (Google / Apple), and set default target language.
- ⌨️ **Custom Shortcut:** Choose from presets like `Option + V` (Windows Win+V style) or record a custom key combination.
- 🔢 **History Limit:** Store 50, 100, 200, or up to 500 clipboard entries.
- 🚀 **Launch at Login:** Automatically start monkey-tools when your Mac boots.
- ⚡ **Auto-Paste:** Enable/disable simulated auto-pasting upon selection.

---

## 🛠️ Build from Source

To compile and package the project manually:

```bash
# Clone the repository
git clone https://github.com/pakkawatkh/monkey-tools.git
cd monkey-tools

# Run full unit test suite (39 tests)
swift test

# Build release application bundle and DMG installer
./scripts/create_dmg.sh
```

---

## 📄 License
Open Source — Licensed under the **[MIT License](LICENSE)**. Copyright © 2026 Pakkawat.k.
