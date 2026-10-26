import Foundation
import Combine

public struct EmojiItem: Identifiable, Hashable {
    public let id = UUID()
    public let char: String
    public let name: String
    public let keywords: String

    public init(_ char: String, _ name: String, _ keywords: String = "") {
        self.char = char
        self.name = name
        self.keywords = keywords
    }
}

public enum EmojiCategory: String, CaseIterable, Identifiable {
    case recent = "🕒"
    case smileys = "😀"
    case gestures = "👋"
    case animals = "🐵"
    case food = "🍔"
    case symbols = "💡"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recent: return "Recent"
        case .smileys: return "Smileys"
        case .gestures: return "People"
        case .animals: return "Animals"
        case .food: return "Food"
        case .symbols: return "Symbols"
        }
    }
}

public final class EmojiManager: ObservableObject {
    public static let shared = EmojiManager()

    @Published public var recentEmojis: [String] = []
    @Published public var selectedCategory: EmojiCategory = .recent
    @Published public var searchQuery: String = ""

    private let recentKey = "monkey_recent_emojis"

    public init() {
        let saved = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        if saved.isEmpty {
            self.recentEmojis = ["🐵", "🐒", "👍", "❤️", "😂", "🔥", "✨", "🙏", "🎉", "🥰", "😍", "😊", "💯", "🚀"]
        } else {
            self.recentEmojis = saved
        }
    }

    public func useEmoji(_ char: String) {
        recentEmojis.removeAll { $0 == char }
        recentEmojis.insert(char, at: 0)
        if recentEmojis.count > 35 {
            recentEmojis = Array(recentEmojis.prefix(35))
        }
        UserDefaults.standard.set(recentEmojis, forKey: recentKey)
    }

    public var filteredEmojis: [String] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            // Search all emojis
            return allEmojis.filter { item in
                item.char.contains(query) ||
                item.name.lowercased().contains(query) ||
                item.keywords.lowercased().contains(query)
            }.map { $0.char }
        }

        switch selectedCategory {
        case .recent:
            return recentEmojis
        case .smileys:
            return smileyList.map { $0.char }
        case .gestures:
            return gestureList.map { $0.char }
        case .animals:
            return animalList.map { $0.char }
        case .food:
            return foodList.map { $0.char }
        case .symbols:
            return symbolList.map { $0.char }
        }
    }

    private var allEmojis: [EmojiItem] {
        return smileyList + gestureList + animalList + foodList + symbolList
    }

    // MARK: - Emoji Data Lists

    private let smileyList: [EmojiItem] = [
        EmojiItem("😀", "Grinning Face", "smile happy ยิ้ม หัวเราะ"),
        EmojiItem("😃", "Grinning Face with Big Eyes", "smile happy ยิ้ม"),
        EmojiItem("😄", "Grinning Face with Smiling Eyes", "smile happy ยิ้ม"),
        EmojiItem("😁", "Beaming Face with Smiling Eyes", "smile grin ยิ้ม"),
        EmojiItem("😆", "Grinning Squinting Face", "laugh haha ขำ"),
        EmojiItem("🥹", "Face Holding Back Tears", "cry tear ซึ้ง น้ำตาคลอ"),
        EmojiItem("😅", "Grinning Face with Sweat", "sweat awkward เขิน เหงื่อตก"),
        EmojiItem("😂", "Face with Tears of Joy", "laugh haha cry ตลก ขำกลิ้ง 555"),
        EmojiItem("🤣", "Rolling on the Floor Laughing", "rofl haha ขำกลิ้ง"),
        EmojiItem("🥲", "Smiling Face with Tear", "smile tear ยิ้มทั้งน้ำตา"),
        EmojiItem("☺️", "Smiling Face", "smile shy เขิน ยิ้ม"),
        EmojiItem("😊", "Smiling Face with Smiling Eyes", "smile happy ยิ้ม"),
        EmojiItem("😇", "Smiling Face with Halo", "angel holy เทวดา คนดี"),
        EmojiItem("🙂", "Slightly Smiling Face", "smile ยิ้มอ่อน"),
        EmojiItem("🙃", "Upside Down Face", "silly sarcasm กวน"),
        EmojiItem("😉", "Winking Face", "wink ขยิบตา"),
        EmojiItem("😌", "Relieved Face", "peace calm โล่งอก สบายใจ"),
        EmojiItem("😍", "Smiling Face with Heart Eyes", "love heart รัก ชอบ หลง"),
        EmojiItem("🥰", "Smiling Face with Hearts", "love in love รัก อบอุ่น"),
        EmojiItem("😘", "Face Blowing a Kiss", "kiss จูบ ส่งจูบ"),
        EmojiItem("😗", "Kissing Face", "kiss จูบ"),
        EmojiItem("😋", "Face Savoring Food", "yummy delicious อร่อย แซ่บ"),
        EmojiItem("😛", "Face with Tongue", "tongue แลบลิ้น"),
        EmojiItem("😜", "Winking Face with Tongue", "silly wink แลบลิ้น ทะเล้น"),
        EmojiItem("🤪", "Zany Face", "crazy silly บ้า รั่ว"),
        EmojiItem("😝", "Squinting Face with Tongue", "silly tease แกล้ง"),
        EmojiItem("🤑", "Money Mouth Face", "money rich รวย เงิน"),
        EmojiItem("🤗", "Hugging Face", "hug กอด"),
        EmojiItem("🤭", "Face with Hand Over Mouth", "giggle oops อุ๊บส์ คิกๆ"),
        EmojiItem("🤫", "Shushing Face", "quiet secret เงียบ ชู่ว"),
        EmojiItem("🤔", "Thinking Face", "think hmm สงสัย คิด"),
        EmojiItem("🫡", "Saluting Face", "salute respect รับทราบ วันทยหัตถ์"),
        EmojiItem("🤐", "Zipper Mouth Face", "silent secret รูดซิป ปิดปาก"),
        EmojiItem("🤨", "Face with Raised Eyebrow", "doubt skeptical หรี่ตา สงสัย"),
        EmojiItem("😐", "Neutral Face", "meh blank เฉย"),
        EmojiItem("😑", "Expressionless Face", "flat blank ไร้อารมณ์"),
        EmojiItem("😶", "Face Without Mouth", "speechless เงียบ"),
        EmojiItem("🫥", "Dotted Line Face", "invisible fade ล่องหน"),
        EmojiItem("😶‍🌫️", "Face in Clouds", "fog cloudy เบลอ งง"),
        EmojiItem("😏", "Smirking Face", "smirk tease ยิ้มมุมปาก"),
        EmojiItem("😒", "Unamused Face", "annoyed เซ็ง"),
        EmojiItem("🙄", "Face with Rolling Eyes", "eyeroll มองบน"),
        EmojiItem("😬", "Grimacing Face", "nervous ยี้ แหะๆ"),
        EmojiItem("😮‍💨", "Face Exhaling", "sigh phew ถอนหายใจ"),
        EmojiItem("🤥", "Lying Face", "lie pinocchio โกหก"),
        EmojiItem("😌", "Relieved", "calm สบาย"),
        EmojiItem("😴", "Sleeping Face", "sleep zzz หลับ นอน"),
        EmojiItem("😷", "Face with Medical Mask", "mask sick ป่วย หน้ากาก"),
        EmojiItem("🤒", "Face with Thermometer", "sick fever เป็นไข้ ป่วย"),
        EmojiItem("🤕", "Face with Head Bandage", "hurt injury เจ็บหัว เจ็บ"),
        EmojiItem("🤢", "Nauseated Face", "sick disgust คลื่นไส้ จะอ้วก"),
        EmojiItem("🤮", "Face Vomiting", "vomit puke อ้วก แหวะ"),
        EmojiItem("🤧", "Sneezing Face", "sneeze จาม"),
        EmojiItem("🥵", "Hot Face", "hot sweat ร้อน"),
        EmojiItem("🥶", "Cold Face", "cold freeze หนาว เย็น"),
        EmojiItem("🥴", "Woozy Face", "drunk dizzy เมา มึน"),
        EmojiItem("😵", "Face with Crossed Out Eyes", "dead dizzy มึน สลบ"),
        EmojiItem("🤯", "Exploding Head", "mindblown หัวระเบิด อึ้ง"),
        EmojiItem("🤠", "Cowboy Hat Face", "cowboy คาวบอย"),
        EmojiItem("🥳", "Partying Face", "party celebrate ปาร์ตี้ ฉลอง"),
        EmojiItem("🥸", "Disguised Face", "disguise แฝงตัว ปลอมตัว"),
        EmojiItem("😎", "Smiling Face with Sunglasses", "cool sunglasses เท่ หล่อ"),
        EmojiItem("🤓", "Nerd Face", "nerd geek เด็กเนิร์ด แว่น"),
        EmojiItem("🧐", "Face with Monocle", "curious ส่อง ตรวจสอบ"),
        EmojiItem("😕", "Confused Face", "confused สับสน"),
        EmojiItem("😟", "Worried Face", "worried กังวล"),
        EmojiItem("🙁", "Slightly Frowning Face", "sad หน้าบึ้ง"),
        EmojiItem("😮", "Face with Open Mouth", "wow surprise อ้าปาก ตกใจ"),
        EmojiItem("😯", "Hushed Face", "hushed เงียบ อึ้ง"),
        EmojiItem("😲", "Astonished Face", "shocked ตกตะลึง"),
        EmojiItem("😳", "Flushed Face", "blush shock ตาโต เขิน หน้าแดง"),
        EmojiItem("🥺", "Pleading Face", "puppy please อ้อน ขอร้อง พลีส"),
        EmojiItem("😦", "Frowning Face with Open Mouth", "sad frown บึ้ง"),
        EmojiItem("😨", "Fearful Face", "scared กลัว"),
        EmojiItem("😰", "Anxious Face with Sweat", "nervous กังวล เหงื่อตก"),
        EmojiItem("😥", "Sad but Relieved Face", "sad phew เศร้า"),
        EmojiItem("😢", "Crying Face", "cry tear ร้องไห้ เสียใจ"),
        EmojiItem("😭", "Loudly Crying Face", "sob cry ร้องไห้โฮ แงๆ"),
        EmojiItem("😱", "Face Screaming in Fear", "scream shocked กรี๊ด กลัวมาก"),
        EmojiItem("😖", "Confounded Face", "frustrated หงุดหงิด"),
        EmojiItem("😣", "Persevering Face", "struggle อดทน"),
        EmojiItem("😞", "Disappointed Face", "sad ผิดหวัง"),
        EmojiItem("😓", "Downcast Face with Sweat", "tired เหนื่อย"),
        EmojiItem("😩", "Weary Face", "tired เหนื่อยล้า"),
        EmojiItem("😫", "Tired Face", "exhausted ไม่ไหวแล้ว"),
        EmojiItem("🥱", "Yawning Face", "yawn หาว ง่วง"),
        EmojiItem("😤", "Face with Steam From Nose", "angry proud ฮึ่ม ฟึดฟัด"),
        EmojiItem("😡", "Enraged Face", "angry pouting โกรธ โมโห"),
        EmojiItem("😠", "Angry Face", "mad โกรธ"),
        EmojiItem("🤬", "Face with Symbols on Mouth", "cursing ด่า สบถ"),
        EmojiItem("😈", "Smiling Face with Horns", "devil evil ปีศาจร้าย"),
        EmojiItem("👿", "Angry Face with Horns", "devil mad ปีศาจโกรธ"),
        EmojiItem("💀", "Skull", "dead skeleton หัวกะโหลก ขิต ตาย"),
        EmojiItem("☠️", "Skull and Crossbones", "danger poison อันตราย"),
        EmojiItem("💩", "Pile of Poo", "poop poo ขี้ อึ"),
        EmojiItem("🤡", "Clown Face", "clown ตัวตลก ตัวตลกโบโซ่"),
        EmojiItem("👻", "Ghost", "spooky ผี กุ๊กกู๋"),
        EmojiItem("👽", "Alien", "ufo เอเลี่ยน มนุษย์ต่างดาว"),
        EmojiItem("🤖", "Robot", "bot หุ่นยนต์ โรบ็อต")
    ]

    private let gestureList: [EmojiItem] = [
        EmojiItem("👋", "Waving Hand", "wave hello bye โบกมือ หวัดดี บาย"),
        EmojiItem("🤚", "Raised Back of Hand", "hand stop มือ"),
        EmojiItem("✋", "Raised Hand", "high five หยุด ห้า"),
        EmojiItem("🖖", "Vulcan Salute", "spock วัลแคน"),
        EmojiItem("🫱", "Rightwards Hand", "hand ขวา"),
        EmojiItem("🫲", "Leftwards Hand", "hand ซ้าย"),
        EmojiItem("🫳", "Palm Down Hand", "hand วาง"),
        EmojiItem("🫴", "Palm Up Hand", "hand หงายมือ ขอ"),
        EmojiItem("👌", "OK Hand", "okay perfect ตกลง โอเค"),
        EmojiItem("🤌", "Pinched Fingers", "italian gesture อะไรนะ"),
        EmojiItem("🤏", "Pinching Hand", "small little นิดเดียว หน่อยนึง"),
        EmojiItem("✌️", "Victory Hand", "peace v สองนิ้ว สู้ๆ"),
        EmojiItem("🤞", "Crossed Fingers", "luck hope ขอให้โชคดี สาธุ"),
        EmojiItem("🫰", "Hand with Index Finger and Thumb Crossed", "finger heart มินิฮาร์ท ซารังเฮ"),
        EmojiItem("🤟", "Love-You Gesture", "ily love รักนะ"),
        EmojiItem("🤘", "Sign of the Horns", "rock on ร็อค"),
        EmojiItem("🤙", "Call Me Hand", "call phone โทรมานะ"),
        EmojiItem("👈", "Backhand Index Pointing Left", "point left ชี้ซ้าย"),
        EmojiItem("👉", "Backhand Index Pointing Right", "point right ชี้ขวา"),
        EmojiItem("👆", "Backhand Index Pointing Up", "point up ชี้บน"),
        EmojiItem("🖕", "Middle Finger", "fu นิ้วกลาง"),
        EmojiItem("👇", "Backhand Index Pointing Down", "point down ชี้ล่าง"),
        EmojiItem("☝️", "Index Pointing Up", "one up ชี้"),
        EmojiItem("🫵", "Index Pointing at the Viewer", "you ชี้คุณ"),
        EmojiItem("👍", "Thumbs Up", "like good เยี่ยม ถูกใจ ใช่ ดี"),
        EmojiItem("👎", "Thumbs Down", "dislike bad ไม่ดี แย่ ไม่ชอบ"),
        EmojiItem("✊", "Raised Fist", "fist power หมัด สู้"),
        EmojiItem("👊", "Oncoming Fist", "punch brofist ชนหมัด ต่อย"),
        EmojiItem("🤛", "Left-Facing Fist", "fist ชนหมัด"),
        EmojiItem("🤜", "Right-Facing Fist", "fist ชนหมัด"),
        EmojiItem("👏", "Clapping Hands", "clap bravo ปรบมือ เยี่ยมยอด"),
        EmojiItem("🙌", "Raising Hands", "cheer celebrate ไชโย สาธุ ยกมือ"),
        EmojiItem("🫶", "Heart Hands", "heart love ทำมือรูปหัวใจ"),
        EmojiItem("👐", "Open Hands", "open hands แบมือ"),
        EmojiItem("🤲", "Palms Up Together", "pray หงายมือ ขอพร"),
        EmojiItem("🤝", "Handshake", "deal agreement จับมือ สัญญา ตกลง"),
        EmojiItem("🙏", "Folded Hands", "please pray thank you ไหว้ ขอบคุณ สาธุ พลีส"),
        EmojiItem("✍️", "Writing Hand", "write เขียน จด"),
        EmojiItem("💅", "Nail Polish", "nails beauty ทาเล็บ เชิด"),
        EmojiItem("🤳", "Selfie", "phone photo เซลฟี่ ถ่ายรูป"),
        EmojiItem("💪", "Flexed Biceps", "muscle strong ฟิต แข็งแรง พลัง"),
        EmojiItem("👀", "Eyes", "look see ตา มอง ส่อง"),
        EmojiItem("👁️", "Eye", "look see ดวงตา"),
        EmojiItem("👅", "Tongue", "taste ลิ้น"),
        EmojiItem("👄", "Mouth", "lips ปาก จูบ")
    ]

    private let animalList: [EmojiItem] = [
        EmojiItem("🐵", "Monkey Face", "monkey primate ลิง หน้ารูปลิง"),
        EmojiItem("🐒", "Monkey", "monkey animal ลิงทั้งตัว"),
        EmojiItem("🦍", "Gorilla", "gorilla ape คิงคอง กอริลล่า"),
        EmojiItem("🦧", "Orangutan", "orangutan อุรังอุตัง"),
        EmojiItem("🐶", "Dog Face", "dog puppy หมา สุนัข หมาน้อย"),
        EmojiItem("🐕", "Dog", "doggy หมา"),
        EmojiItem("🐩", "Poodle", "poodle พุดเดิ้ล"),
        EmojiItem("🐺", "Wolf", "wolf หมาป่า"),
        EmojiItem("🦊", "Fox", "fox จิ้งจอก"),
        EmojiItem("🦝", "Raccoon", "raccoon แรคคูน"),
        EmojiItem("🐱", "Cat Face", "cat kitty แมว เหมียว"),
        EmojiItem("🐈", "Cat", "kitten แมว"),
        EmojiItem("🦁", "Lion", "lion สิงโต เจ้าป่า"),
        EmojiItem("🐯", "Tiger Face", "tiger เสือ ลายพาดกลอน"),
        EmojiItem("🐅", "Tiger", "tiger เสือ"),
        EmojiItem("🐆", "Leopard", "leopard เสือดาว"),
        EmojiItem("🐴", "Horse Face", "horse ม้า"),
        EmojiItem("🦄", "Unicorn", "unicorn magic ยูนิคอร์น"),
        EmojiItem("🦓", "Zebra", "zebra ม้าลาย"),
        EmojiItem("🦌", "Deer", "deer กวาง"),
        EmojiItem("🐮", "Cow Face", "cow วัว วัวน้อย"),
        EmojiItem("🐷", "Pig Face", "pig หมู อู๊ดๆ"),
        EmojiItem("🐗", "Boar", "boar หมูป่า"),
        EmojiItem("🐭", "Mouse Face", "mouse rat หนู"),
        EmojiItem("🐰", "Rabbit Face", "rabbit bunny กระต่าย"),
        EmojiItem("🐿️", "Chipmunk", "chipmunk กระรอก"),
        EmojiItem("🦔", "Hedgehog", "hedgehog เม่น"),
        EmojiItem("🐻", "Bear", "bear หมี"),
        EmojiItem("🐨", "Koala", "koala โคอาล่า"),
        EmojiItem("🐼", "Panda", "panda แพนด้า"),
        EmojiItem("🦥", "Sloth", "sloth สลอธ ชิล"),
        EmojiItem("🦦", "Otter", "otter นาก"),
        EmojiItem("🦘", "Kangaroo", "kangaroo จิงโจ้"),
        EmojiItem("🐾", "Paw Prints", "paws รอยเท้าสัตว์ รอยเท้าแมว"),
        EmojiItem("🐔", "Chicken", "chicken ไก่"),
        EmojiItem("🐧", "Penguin", "penguin เพนกวิน"),
        EmojiItem("🐦", "Bird", "bird นก"),
        EmojiItem("🦅", "Eagle", "eagle อินทรี"),
        EmojiItem("🦉", "Owl", "owl นกฮูก"),
        EmojiItem("🦇", "Bat", "bat ค้างคาว"),
        EmojiItem("🦋", "Butterfly", "butterfly ผีเสื้อ"),
        EmojiItem("🐝", "Honeybee", "bee ผึ้ง"),
        EmojiItem("🐢", "Turtle", "turtle เต่า"),
        EmojiItem("🐍", "Snake", "snake งู"),
        EmojiItem("🐬", "Dolphin", "dolphin โลมา"),
        EmojiItem("🐳", "Whale", "whale วาฬ"),
        EmojiItem("🦈", "Shark", "shark ฉลาม"),
        EmojiItem("🐙", "Octopus", "octopus ปลาหมึก"),
        EmojiItem("🌸", "Cherry Blossom", "flower sakura ซากุระ ดอกไม้"),
        EmojiItem("🌹", "Rose", "rose กุหลาบ ดอกไม้"),
        EmojiItem("🌻", "Sunflower", "sunflower ทานตะวัน"),
        EmojiItem("🍀", "Four Leaf Clover", "lucky โชคดี โคลเวอร์"),
        EmojiItem("🍁", "Maple Leaf", "maple ใบเมเปิ้ล"),
        EmojiItem("🍄", "Mushroom", "mushroom เห็ด")
    ]

    private let foodList: [EmojiItem] = [
        EmojiItem("🍌", "Banana", "banana monkey กล้วย"),
        EmojiItem("🍎", "Red Apple", "apple แอปเปิ้ล"),
        EmojiItem("🍊", "Tangerine", "orange ส้ม"),
        EmojiItem("🍋", "Lemon", "lemon มะนาว"),
        EmojiItem("🍉", "Watermelon", "watermelon แตงโม"),
        EmojiItem("🍇", "Grapes", "grapes องุ่น"),
        EmojiItem("🍓", "Strawberry", "strawberry สตรอว์เบอร์รี"),
        EmojiItem("🍒", "Cherries", "cherry เชอร์รี่"),
        EmojiItem("🍑", "Peach", "peach ลูกพีช ก้น"),
        EmojiItem("🥭", "Mango", "mango มะม่วง"),
        EmojiItem("🍍", "Pineapple", "pineapple สับปะรด"),
        EmojiItem("🥥", "Coconut", "coconut มะพร้าว"),
        EmojiItem("🥑", "Avocado", "avocado อะโวคาโด"),
        EmojiItem("🍔", "Hamburger", "burger แฮมเบอร์เกอร์"),
        EmojiItem("🍟", "French Fries", "fries เฟรนช์ฟรายส์"),
        EmojiItem("🍕", "Pizza", "pizza พิซซ่า"),
        EmojiItem("🌭", "Hot Dog", "hotdog ฮอตด็อก"),
        EmojiItem("🥪", "Sandwich", "sandwich แซนวิช"),
        EmojiItem("🌮", "Taco", "taco ทาโก้"),
        EmojiItem("🍜", "Steaming Bowl", "noodles ramen ก๋วยเตี๋ยว ราเมง"),
        EmojiItem("🍝", "Spaghetti", "pasta สปาเก็ตตี้"),
        EmojiItem("🍣", "Sushi", "sushi ซูชิ ปลาดิบ"),
        EmojiItem("🍱", "Bento Box", "bento ข้าวกล่อง"),
        EmojiItem("🥟", "Dumpling", "dumpling เกี๊ยวซ่า"),
        EmojiItem("🍤", "Fried Shrimp", "tempura กุ้งทอด"),
        EmojiItem("🍦", "Soft Ice Cream", "ice cream ไอศกรีม ไอติม"),
        EmojiItem("🍧", "Shaved Ice", "ice น้ำแข็งไส"),
        EmojiItem("🎂", "Birthday Cake", "cake เค้ก วันเกิด"),
        EmojiItem("🍰", "Shortcake", "cake เค้ก"),
        EmojiItem("🍩", "Doughnut", "donut โดนัท"),
        EmojiItem("🍪", "Cookie", "cookie คุกกี้"),
        EmojiItem("🍫", "Chocolate Bar", "chocolate ช็อกโกแลต"),
        EmojiItem("🍿", "Popcorn", "popcorn ป๊อปคอร์น"),
        EmojiItem("☕", "Hot Beverage", "coffee tea กาแฟ ชา"),
        EmojiItem("🧋", "Bubble Tea", "boba ชานมไข่มุก"),
        EmojiItem("🍺", "Beer Mug", "beer เบียร์ ชนแก้ว"),
        EmojiItem("🍻", "Clinking Beer Mugs", "cheers ชนแก้ว ปาร์ตี้"),
        EmojiItem("🥂", "Clinking Glasses", "wine champagne แชมเปญ ฉลอง"),
        EmojiItem("🍷", "Wine Glass", "wine ไวน์"),
        EmojiItem("🧃", "Beverage Box", "juice น้ำผลไม้ กล่อง")
    ]

    private let symbolList: [EmojiItem] = [
        EmojiItem("❤️", "Red Heart", "heart love หัวใจ รัก แดง"),
        EmojiItem("🧡", "Orange Heart", "heart ส้ม"),
        EmojiItem("💛", "Yellow Heart", "heart เหลือง"),
        EmojiItem("💚", "Green Heart", "heart เขียว"),
        EmojiItem("💙", "Blue Heart", "heart ฟ้า น้ำเงิน"),
        EmojiItem("💜", "Purple Heart", "heart ม่วง"),
        EmojiItem("🖤", "Black Heart", "heart ดำ"),
        EmojiItem("🤍", "White Heart", "heart ขาว"),
        EmojiItem("💔", "Broken Heart", "heartbreak อกหัก เสียใจ"),
        EmojiItem("❤️‍🔥", "Heart on Fire", "passion ไฟลุก ร้อนแรง"),
        EmojiItem("✨", "Sparkles", "glitter shine วิบวับ ประกาย ดาว"),
        EmojiItem("⭐", "Star", "star ดาว ยอดเยี่ยม"),
        EmojiItem("🌟", "Glowing Star", "star ดาวส่องแสง"),
        EmojiItem("🔥", "Fire", "flame lit hot ไฟ ร้อนแรง เดือด"),
        EmojiItem("💥", "Collision", "boom ระเบิด ปัง"),
        EmojiItem("💯", "Hundred Points", "100 perfect เต็มร้อย สุดยอด"),
        EmojiItem("🎉", "Party Popper", "celebrate เย้ ฉลอง ยินดี"),
        EmojiItem("🎊", "Confetti Ball", "celebrate ฉลอง"),
        EmojiItem("🏆", "Trophy", "winner ถ้วยรางวัล ชนะ"),
        EmojiItem("🥇", "1st Place Medal", "gold winner เหรียญทอง อันดับ1"),
        EmojiItem("🎯", "Bullseye", "target เป้าหมาย ตรงเป้า"),
        EmojiItem("🚀", "Rocket", "launch fast จรวด พุ่ง"),
        EmojiItem("💡", "Light Bulb", "idea bright ไอเดีย ความคิด หลอดไฟ"),
        EmojiItem("⚡", "High Voltage", "lightning power สายฟ้า ไฟฟ้า รวดเร็ว"),
        EmojiItem("💎", "Gem Stone", "diamond เพชร เลอค่า"),
        EmojiItem("💰", "Money Bag", "money ถุงเงิน รวย"),
        EmojiItem("💵", "Dollar Banknote", "cash เงิน ดอลลาร์"),
        EmojiItem("🔔", "Bell", "notification กระดิ่ง แจ้งเตือน"),
        EmojiItem("📌", "Pushpin", "pin หมุด ปักหมุด"),
        EmojiItem("📍", "Round Pushpin", "location ปักหมุด ที่ตั้ง"),
        EmojiItem("📎", "Paperclip", "clip คลิปหนีบกระดาษ"),
        EmojiItem("💻", "Laptop", "computer โน้ตบุ๊ก คอมพิวเตอร์"),
        EmojiItem("📱", "Mobile Phone", "phone มือถือ โทรศัพท์"),
        EmojiItem("✅", "Check Mark Button", "check ok ถูกต้อง เสร็จ เรียบร้อย"),
        EmojiItem("❌", "Cross Mark", "no cancel ผิด กากบาท"),
        EmojiItem("⚠️", "Warning", "alert เตือน ระวัง"),
        EmojiItem("⛔", "No Entry", "stop ห้ามเข้า ห้าม"),
        EmojiItem("❓", "Question Mark", "help คำถาม สงสัย"),
        EmojiItem("❗", "Exclamation Mark", "alert สำคัญ ตกใจ"),
        EmojiItem("💬", "Speech Balloon", "chat talk แชท ข้อความ"),
        EmojiItem("🎶", "Musical Notes", "music เพลง ดนตรี"),
        EmojiItem("🎵", "Musical Note", "music ตัวโน้ต")
    ]
}
