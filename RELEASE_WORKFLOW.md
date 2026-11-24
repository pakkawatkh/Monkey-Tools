# 🚀 คู่มือขั้นตอนการพัฒนาและปล่อยอัปเดต (Dev & Release Workflow)

เอกสารสรุปขั้นตอนการแก้ไขโค้ด ทดสอบ แพ็กเกจไฟล์ ไปจนถึงการ Deploy ขึ้นหน้าเว็บและระบบ In-App Auto-Updater โดยใช้ Relative Path เพื่อให้รันได้บนทุกเครื่อง

---

## 🛠️ Step 1: พัฒนาและทดสอบ (Local Development & Testing)

1. แก้ไขโค้ดใน `Sources/MonkeyTools/` และเพิ่ม/แก้ไข Unit Tests ใน `Tests/MonkeyToolsTests/`
2. รัน Unit Tests ทั้งหมดให้ผ่าน:
   ```bash
   swift test
   ```
3. ทดลอง Build และติดตั้งลง `/Applications/monkey-tools.app` เพื่อทดสอบใช้งานจริงบนเครื่อง:
   ```bash
   ./scripts/build_app.sh
   open /Applications/monkey-tools.app
   ```

---

## 🏷️ Step 2: อัปเดตเลขเวอร์ชันและแพ็กเกจไฟล์ (Version Bump & Packaging)

1. **แก้เลขเวอร์ชันใน `scripts/build_app.sh`:**
   อัปเดตค่า `CFBundleShortVersionString` และ `CFBundleVersion` (เช่น `X.Y.Z`)
2. **รันสคริปต์สร้าง DMG และ ZIP:**
   ```bash
   ./scripts/create_dmg.sh
   ```
   *(สคริปต์จะ Build Release, สร้าง `.app`, `.dmg`, `.zip` และคัดลอกไปยัง `./docs/` และ `../pliw-app/monkey-tools/` อัตโนมัติ)*

---

## 🌐 Step 3: อัปเดตข้อมูลเวอร์ชันและหน้าเว็บที่ Release Portal (`../pliw-app`)

1. **อัปเดตไฟล์ `../pliw-app/monkey-tools/version.json`:**
   อัปเดต `"latestVersion"`, `"releaseNotes"`, และ `"releaseDate"` (YYYY-MM-DD)
2. **อัปเดตเลขเวอร์ชันบนหน้าเว็บไซต์:**
   - `../pliw-app/index.html`
   - `../pliw-app/monkey-tools/index.html`

---

## 🚢 Step 4: Commit & Deploy ขึ้น GitHub (ทั้ง 2 Repos)

```bash
# 1. Push ซอร์สโค้ดขึ้น Repo ของแอป
git add .
git commit -m "feat: release vX.Y.Z - <สรุปการเปลี่ยนแปลง>"
git push origin main

# 2. Push ไฟล์ติดตั้งและหน้าเว็บขึ้น Release Portal (../pliw-app)
cd ../pliw-app
git add monkey-tools/ index.html
git commit -m "chore(release): update monkey-tools to vX.Y.Z"
git push origin main
```
