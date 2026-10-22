# 🐵 monkey-copy 📋
> **Windows-style Clipboard History (`Win + V`) for macOS with Customizable Shortcut & Image Support**

**monkey-copy** เป็นแอพพลิเคชัน Clipboard Manager สุดน่ารักสำหรับ macOS พัฒนาด้วย Swift และ SwiftUI ให้มีความกะทัดรัด (ความกว้าง 320px) รวดเร็ว น้ำหนักเบา และมาพร้อมไอคอนรูปลิง 🐵
- ⌨️ กดคีย์ลัดสากล (ค่าเริ่มต้น `Command + Shift + V` หรือเลือกปรับเป็น `Option + V` ได้)
- 📝 เก็บประวัติข้อความที่ Copy ไว้ได้หลายรายการ
- 🖼️ รองรับการ Copy รูปภาพ (Screenshot, ภาพจากเบราว์เซอร์, ไฟล์ภาพ)
- ⚡ วางข้อความหรือรูปภาพลงในโปรแกรมที่กำลังใช้งานอยู่ให้อัตโนมัติ (Auto-Paste)
- ⚙️ มีระบบ Config ให้ปรับแต่งคีย์ลัดได้ตามต้องการ

---

## 📦 ตัวติดตั้ง (Installer)

ติดตั้งง่ายๆ ผ่านไฟล์ตัวติดตั้งมาตรฐานของ macOS:

👉 **[monkey-copy-Installer.dmg](file:///Users/pakkawat/Documents/clipboard/monkey-copy-Installer.dmg)**
- ดับเบิ้ลคลิกเปิดไฟล์ `monkey-copy-Installer.dmg`
- ลากไอคอน **monkey-copy** ไปวางที่ไอคอนโฟลเดอร์ **Applications**
- เปิดใช้งานได้ทันทีจาก Spotlight (`Cmd + Space` แล้วพิมพ์ monkey-copy) หรือ Launchpad

---

## ⚙️ การตั้งค่าและปรับเปลี่ยนคีย์ลัด (Settings)

เปิดหน้าต่าง Settings ได้ 2 ทาง:
1. กดไอคอนรูปฟันเฟือง **⚙️** ที่มุมขวาบนของหน้าต่าง Clipboard
2. หรือคลิกที่ไอคอน 📋 บนแถบ Menu Bar ด้านบน แล้วเลือก **Settings...**

### สิ่งที่ปรับแต่งได้:
- ⌨️ **เปลี่ยนคีย์ลัด:** เลือก Preset เช่น `Option + V`, `Command + Shift + V` หรือกดบันทึกคีย์ลัดใหม่ด้วยตัวเอง
- 🔢 **ประวัติสูงสุดที่บันทึก:** เลือกได้ 50, 100, 200, หรือ 500 รายการ
- 🚀 **Launch at Login:** เปิดแอพอัตโนมัติเมื่อเปิดเครื่อง
- ⚡ **Auto-Paste:** เปิด/ปิดการวางอัตโนมัติ

---

## 🔒 การให้สิทธิ์การวางอัตโนมัติ (Accessibility Permission)

เพื่อให้แอพสามารถกด `Cmd + V` วางข้อความและรูปภาพลงในโปรแกรมอื่นให้อัตโนมัติ:
1. ไปที่ **System Settings** > **Privacy & Security** > **Accessibility**
2. เปิดสวิตช์อนุญาตให้กับ **monkey-copy**
