import Foundation
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case th = "th"
    case en = "en"
    case zh = "zh"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return "🌐 ตามระบบเครื่อง (System)"
        case .th:
            return "🇹🇭 ไทย (Thai)"
        case .en:
            return "🇺🇸 English"
        case .zh:
            return "🇨🇳 中文 (简体)"
        }
    }
}

public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public private(set) var currentLanguage: AppLanguage = .system
    @Published public private(set) var effectiveLanguageCode: String = "th"

    private let stringsTable: [String: [String: String]] = [
        // Tab / Navigation
        "tab_clipboard": ["th": "คลิปบอร์ด", "en": "Clipboard", "zh": "剪贴板"],
        "tab_emoji": ["th": "อีโมจิ", "en": "Emoji", "zh": "表情符号"],
        "tab_all": ["th": "ทั้งหมด", "en": "All", "zh": "全部"],
        "tab_text": ["th": "ข้อความ", "en": "Text", "zh": "文本"],
        "tab_image": ["th": "รูปภาพ", "en": "Images", "zh": "图片"],
        "tab_pinned": ["th": "ตรึงไว้", "en": "Pinned", "zh": "已固定"],

        // Clipboard Actions & Hints
        "search_placeholder": ["th": "ค้นหาประวัติคลิปบอร์ด... (↑↓)", "en": "Search history... (↑↓)", "zh": "搜索剪贴板历史... (↑↓)"],
        "search_emoji_placeholder": ["th": "ค้นหาอีโมจิ...", "en": "Search emoji...", "zh": "搜索表情符号..."],
        "clear_history": ["th": "ล้างประวัติ", "en": "Clear history", "zh": "清空历史"],
        "clear_history_alert_title": ["th": "ล้างประวัติคลิปบอร์ด?", "en": "Clear clipboard history?", "zh": "清空剪贴板历史？"],
        "clear_history_alert_msg": ["th": "คุณต้องการล้างเฉพาะที่ไม่ได้ตรึงไว้ หรือล้างทั้งหมด?", "en": "Do you want to clear unpinned history or everything?", "zh": "您想仅清空未固定的条目，还是清空全部？"],
        "clear_keep_pinned": ["th": "ล้าง (เก็บที่ตรึงไว้)", "en": "Clear (Keep Pinned)", "zh": "清空 (保留已固定)"],
        "clear_everything": ["th": "ล้างทั้งหมด", "en": "Clear Everything", "zh": "清空全部"],
        "cancel": ["th": "ยกเลิก", "en": "Cancel", "zh": "取消"],
        "clipboard_empty": ["th": "ไม่มีประวัติคลิปบอร์ด", "en": "Clipboard is empty", "zh": "暂无剪贴板历史"],
        "clipboard_empty_hint": ["th": "คัดลอกข้อความหรือรูปภาพ (⌘C) เพื่อเริ่มบันทึกประวัติ", "en": "Copy text or images (⌘C) to build your history.", "zh": "复制文本或图片 (⌘C) 开始记录历史。"],
        "no_results": ["th": "ไม่พบผลลัพธ์", "en": "No results found", "zh": "未找到匹配项"],
        "no_results_hint": ["th": "ลองค้นหาด้วยคำอื่น", "en": "Try a different search term.", "zh": "请尝试其他关键词。"],
        "click_emoji_hint": ["th": "คลิกอีโมจิเพื่อวางลงในแอปทันที", "en": "Click any emoji to paste directly", "zh": "点击任意表情符号直接粘贴"],
        "shortcut_esc": ["th": "Esc ปิด", "en": "Esc Close", "zh": "Esc 关闭"],
        "shortcut_enter_paste": ["th": "Enter วาง", "en": "Enter Paste", "zh": "Enter 粘贴"],
        "pin_item": ["th": "ตรึงไว้ด้านบน", "en": "Pin to top", "zh": "固定到顶部"],
        "unpin_item": ["th": "เลิกตรึง", "en": "Unpin", "zh": "取消固定"],
        "delete_item": ["th": "ลบรายการ", "en": "Delete item", "zh": "删除条目"],
        "enable_accessibility": ["th": "เปิดใช้งาน Accessibility เพื่อให้วางอัตโนมัติได้", "en": "Enable Accessibility to Auto-Paste", "zh": "启用辅助功能以支持自动粘贴"],
        "enable_btn": ["th": "เปิดใช้งาน", "en": "Enable", "zh": "启用"],
        "items_count": ["th": "รายการ", "en": "items", "zh": "条"],
        "records_count_suffix": ["th": "รายการ", "en": "items", "zh": "条"],

        // Translation Popover
        "trans_original": ["th": "ข้อความต้นฉบับ", "en": "Original Text", "zh": "原文"],
        "trans_result": ["th": "คำแปล", "en": "Translation", "zh": "译文"],
        "trans_copy": ["th": "คัดลอก", "en": "Copy", "zh": "复制"],
        "trans_copied": ["th": "คัดลอกแล้ว!", "en": "Copied!", "zh": "已复制!"],
        "trans_replace": ["th": "แทนที่คำเดิม", "en": "Replace Original Text", "zh": "替换原文"],
        "trans_auto": ["th": "🌐 ตรวจจับอัตโนมัติ (Auto)", "en": "🌐 Auto Detect", "zh": "🌐 自动检测"],
        "trans_auto_short": ["th": "🌐 ตรวจจับ", "en": "🌐 Auto", "zh": "🌐 自动"],
        "trans_reading": ["th": "กำลังอ่าน...", "en": "Reading...", "zh": "朗读中..."],
        "trans_listen_orig": ["th": "ฟังเสียงอ่านข้อความต้นฉบับ", "en": "Listen to original text", "zh": "朗读原文"],
        "trans_listen_trans": ["th": "ฟังเสียงอ่านคำแปล", "en": "Listen to translation", "zh": "朗读译文"],
        "trans_swap": ["th": "สลับภาษาต้นทางและปลายทาง (Swap Languages)", "en": "Swap source and target languages", "zh": "交换源语言和目标语言"],
        "trans_resize": ["th": "ลากเพื่อยืดหดขยายขนาดหน้าต่าง (Drag to resize)", "en": "Drag to resize window", "zh": "拖动调整窗口大小"],
        "trans_engine_help": ["th": "เครื่องมือแปลภาษาปัจจุบัน (คลิกเพื่อสลับ Google / Apple)", "en": "Current translation engine (Click to toggle Google / Apple)", "zh": "当前翻译引擎 (点击切换 Google / Apple)"],
        "cat_popular": ["th": "ภาษาที่ใช้บ่อย", "en": "Popular Languages", "zh": "常用语言"],
        "cat_asia": ["th": "🌏 เอเชีย & อาเซียน", "en": "🌏 Asia & ASEAN", "zh": "🌏 亚洲与东盟"],
        "cat_europe": ["th": "🌍 ยุโรป", "en": "🌍 Europe", "zh": "🌍 欧洲"],
        "cat_middle_east": ["th": "🌍 ตะวันออกกลาง & อื่นๆ", "en": "🌍 Middle East & Others", "zh": "🌍 中东及其他"],

        // Settings Window
        "settings_title": ["th": "การตั้งค่า monkey-tools", "en": "monkey-tools Settings", "zh": "monkey-tools 设置"],
        "settings_general": ["th": "ทั่วไป (General)", "en": "General", "zh": "通用"],
        "settings_hotkey": ["th": "คีย์ลัด (Hotkeys)", "en": "Hotkeys", "zh": "快捷键"],
        "settings_translator": ["th": "การแปลภาษา (Selection Translator)", "en": "Selection Translator", "zh": "划词翻译"],
        "app_language": ["th": "ภาษาของโปรแกรม (App Language):", "en": "App Language:", "zh": "界面语言："],
        "app_language_desc": ["th": "เลือกภาษาที่ใช้แสดงผลในเมนูและหน้าต่างทั้งหมด", "en": "Choose display language for menus and windows", "zh": "选择菜单和界面的显示语言"],
        "settings_launch_login": ["th": "เปิดโปรแกรมอัตโนมัติเมื่อเปิดเครื่อง (Launch at Login)", "en": "Launch automatically at login", "zh": "开机自动启动"],
        "settings_launch_login_desc": ["th": "เริ่มทำงานในแถบ Menu Bar ทันทีเมื่อเข้าสู่ระบบ", "en": "Start in Menu Bar immediately on login", "zh": "登录系统后立即在菜单栏运行"],
        "settings_auto_paste": ["th": "วางข้อความอัตโนมัติ (Auto-Paste)", "en": "Auto-Paste into active app", "zh": "自动粘贴到当前应用"],
        "settings_auto_paste_desc": ["th": "เมื่อคลิกรายการหรือกด Enter จะวางลงในโปรแกรมที่กำลังใช้งานทันที", "en": "Paste into active application immediately on click or Enter", "zh": "点击条目或按回车时立即粘贴到当前应用"],
        "settings_max_records": ["th": "จำนวนประวัติสูงสุดที่บันทึก:", "en": "Maximum clipboard history:", "zh": "最大记录数："],
        "settings_hotkey_heading": ["th": "คีย์ลัดสำหรับเปิดหน้าต่างคลิปบอร์ด", "en": "Global Shortcut for Clipboard Window", "zh": "打开剪贴板窗口的全局快捷键"],
        "settings_hotkey_sub": ["th": "กดคีย์ลัดนี้ได้จากทุกโปรแกรมเพื่อเปิดหน้าต่างประวัติคลิปบอร์ด", "en": "Press this shortcut from anywhere to open clipboard history", "zh": "随时随地按此快捷键打开剪贴板历史"],
        "settings_custom_hotkey": ["th": "กำหนดคีย์ลัดเอง", "en": "Custom Shortcut", "zh": "自定义快捷键"],
        "settings_press_shortcut": ["th": "กดปุ่มคีย์บอร์ดที่ต้องการ...", "en": "Press desired shortcut keys...", "zh": "按下所需的快捷键组合..."],
        "settings_click_to_record": ["th": "คลิกเพื่อบันทึกคีย์ลัดใหม่", "en": "Click to record shortcut", "zh": "点击录制新快捷键"],
        "settings_bubble_toggle": ["th": "แสดงไอคอนแปลภาษาเมื่อคุมดำข้อความ (Selection Bubble)", "en": "Show floating bubble on text selection", "zh": "划词时显示浮动翻译图标"],
        "settings_bubble_desc": ["th": "เมื่อใช้เมาส์คลุมดำข้อความในโปรแกรมใดๆ จะมีไอคอนเล็กๆ ลอยขึ้นมาให้กดแปลภาษา", "en": "A compact floating icon appears when text is selected in any app", "zh": "在任何应用中选中文本时显示微型浮动翻译图标"],
        "settings_engine_label": ["th": "เครื่องมือแปลภาษา (Translation Engine):", "en": "Translation Engine:", "zh": "翻译引擎："],
        "settings_target_label": ["th": "ภาษาปลายทางที่จำไว้ (Target Language):", "en": "Preferred Target Language:", "zh": "记忆的目标语言："],
        "settings_target_desc": ["th": "แปลเป็นภาษานี้เสมอจนกว่าจะเลือกเปลี่ยนใหม่", "en": "Always translate to this language until changed", "zh": "始终翻译为此语言，直到手动更改"],
        "settings_tip_text": ["th": "💡 คุณยังสามารถคลิกสลับระหว่าง Google Translate และ Apple Native ได้โดยตรงจากหน้าต่างป็อปอัปคำแปล", "en": "💡 You can also toggle between Google Translate and Apple Native directly in the translation popover.", "zh": "💡 您也可以直接在翻译弹窗中切换 Google Translate 和 Apple 原生翻译。"],

        // Network Monitor
        "settings_network_heading": ["th": "🌐 ตรวจสอบความเร็วเน็ต (Network Monitor)", "en": "🌐 Network Monitor", "zh": "🌐 网络监控"],
        "settings_network_enable": ["th": "เปิดใช้งานการตรวจสอบความเร็วเน็ตบน Menu Bar", "en": "Show real-time network speed in Menu Bar", "zh": "在菜单栏显示实时网速"],
        "settings_network_unit": ["th": "หน่วยความเร็ว (Speed Unit)", "en": "Speed Unit", "zh": "网速单位"],
        "unit_auto_bytes": ["th": "Auto (B/s, KB/s, MB/s)", "en": "Auto (B/s, KB/s, MB/s)", "zh": "自动 (B/s, KB/s, MB/s)"],
        "unit_bits": ["th": "Bits (Kbps, Mbps)", "en": "Bits (Kbps, Mbps)", "zh": "比特 (Kbps, Mbps)"],
        "unit_fixed_kb": ["th": "Fixed KB/s", "en": "Fixed KB/s", "zh": "固定 KB/s"],
        "unit_fixed_mb": ["th": "Fixed MB/s", "en": "Fixed MB/s", "zh": "固定 MB/s"],
        "menu_network_speed": ["th": "เน็ตสด", "en": "Network Speed", "zh": "实时网速"],
        "menu_network_session_total": ["th": "ยอดเซสชัน", "en": "Session Data", "zh": "本次流量"],

        // Status Menu Bar
        "menu_show_monkey": ["th": "เปิด monkey-tools", "en": "Show monkey-tools", "zh": "打开 monkey-tools"],
        "menu_history_count": ["th": "ประวัติ:", "en": "History:", "zh": "历史记录："],
        "menu_clear_unpinned": ["th": "ล้างประวัติที่ไม่ตรึง", "en": "Clear Unpinned History", "zh": "清空未固定记录"],
        "menu_clear_all": ["th": "ล้างประวัติทั้งหมด", "en": "Clear All History", "zh": "清空所有记录"],
        "menu_access_granted": ["th": "✓ ได้รับสิทธิ์ Accessibility แล้ว", "en": "✓ Accessibility Granted", "zh": "✓ 已获得辅助功能权限"],
        "menu_access_enable": ["th": "⚠️ เปิดการตั้งค่า Accessibility...", "en": "⚠️ Enable Accessibility...", "zh": "⚠️ 开启辅助功能权限..."],
        "menu_settings_item": ["th": "การตั้งค่า...", "en": "Settings...", "zh": "偏好设置..."],
        "menu_quit_item": ["th": "ออกจาก monkey-tools", "en": "Quit monkey-tools", "zh": "退出 monkey-tools"]
    ]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_ui_language") ?? "system"
        setLanguage(fromCode: saved)
    }

    public func setLanguage(fromCode code: String) {
        let lang = AppLanguage(rawValue: code) ?? .system
        self.currentLanguage = lang
        self.effectiveLanguageCode = resolveEffectiveCode(for: lang)
    }

    public func resolveEffectiveCode(for lang: AppLanguage) -> String {
        switch lang {
        case .th:
            return "th"
        case .en:
            return "en"
        case .zh:
            return "zh"
        case .system:
            if let pref = Locale.preferredLanguages.first?.lowercased() {
                if pref.starts(with: "th") { return "th" }
                if pref.starts(with: "zh") { return "zh" }
                return "en"
            }
            return "en"
        }
    }

    public func localized(_ key: String) -> String {
        let code = effectiveLanguageCode
        if let table = stringsTable[key], let val = table[code] {
            return val
        }
        return stringsTable[key]?["en"] ?? stringsTable[key]?["th"] ?? key
    }

    public subscript(_ key: String) -> String {
        return localized(key)
    }
}
