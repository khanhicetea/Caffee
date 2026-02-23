//
//  TiengViet.swift
//  Caffee
//
//  Created by KhanhIceTea on 24/02/2024.
//

// MARK: - Kiến trúc Engine tiếng Việt (Vietnamese Input Engine Architecture)
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        LUỒNG XỬ LÝ (Processing Flow)                        │
// │                                                                              │
// │  Bàn phím (Keyboard Input)                                                   │
// │       │                                                                      │
// │       ▼                                                                      │
// │  ┌─────────────┐    ┌──────────────────┐                                     │
// │  │ Telex/VNI   │───▶│ TiengVietState   │  Container trạng thái bất biến      │
// │  │ (phương     │    │ - chuKhongDau    │  Mỗi mutation trả về state mới      │
// │  │  thức gõ)   │    │ - dauThanh       │                                     │
// │  └─────────────┘    │ - dauMu          │                                     │
// │                     │ - gachD          │                                     │
// │                     └────────┬─────────┘                                     │
// │                              │                                               │
// │                              ▼                                               │
// │                     ┌──────────────────┐                                     │
// │                     │ TiengVietParser  │  Hàm thuần: [Character] → TPT       │
// │                     └────────┬─────────┘                                     │
// │                              │                                               │
// │                              ▼                                               │
// │                     ┌──────────────────┐                                     │
// │                     │ ThanhPhanTieng   │  Các thành phần âm tiết đã phân     │
// │                     │ - phuAmDau       │  tích: Phụ âm đầu + Nguyên âm +     │
// │                     │ - nguyenAm       │  Phụ âm cuối + Phần dư              │
// │                     │ - phuAmCuoi      │                                     │
// │                     │ - conLai         │                                     │
// │                     └────────┬─────────┘                                     │
// │                              │                                               │
// │              ┌───────────────┼───────────────┐                               │
// │              ▼                               ▼                               │
// │     ┌──────────────────┐           ┌──────────────────┐                      │
// │     │TiengVietValidator│           │TiengVietTransform│                      │
// │     │ - needsRecovery  │           │ - transform()    │                      │
// │     └────────┬─────────┘           └────────┬─────────┘                      │
// │              │                              │                                │
// │              ▼                              ▼                                │
// │     Nếu âm tiết không hợp lệ       Chuỗi tiếng Việt                          │
// │     → Dùng chuỗi gốc               có dấu                                    │
// │                                                                              │
// └─────────────────────────────────────────────────────────────────────────────┘
//
// CÁC FILE:
// - TiengViet.swift       : Kiểu dữ liệu (DauThanh, DauMu, ThanhPhanTieng) + Hằng số
// - TiengVietState.swift  : Trạng thái bất biến với các mutation trả về state mới
// - TiengVietParser.swift : Hàm thuần phân tích: [Character] → ThanhPhanTieng
// - TiengVietTransformer.swift : Hàm thuần biến đổi: ThanhPhanTieng → String
// - TiengVietValidator.swift   : Kiểm tra tính hợp lệ của âm tiết tiếng Việt
// - Telex.swift / VNI.swift    : Triển khai các phương thức gõ

import Foundation

// MARK: - Enums (Dấu tiếng Việt)

/// DauThanh - 6 thanh điệu tiếng Việt
///
/// Tiếng Việt là ngôn ngữ thanh điệu với 6 thanh:
/// ```
/// ┌──────────┬────────┬─────────┬──────────────────────┐
/// │ Thanh    │ Ký hiệu│ Ví dụ   │ Mô tả                │
/// ├──────────┼────────┼─────────┼──────────────────────┤
/// │ bang     │ (không)│ ma      │ Thanh ngang          │
/// │ sac      │   ´    │ má      │ Thanh sắc            │
/// │ huyen    │   `    │ mà      │ Thanh huyền          │
/// │ hoi      │   ˀ    │ mả      │ Thanh hỏi            │
/// │ nga      │   ~    │ mã      │ Thanh ngã            │
/// │ nang     │   .    │ mạ      │ Thanh nặng           │
/// └──────────┴────────┴─────────┴──────────────────────┘
/// ```
enum DauThanh: UInt8 {
  case bang = 0    // Thanh ngang (không dấu)
  case sac = 2     // Thanh sắc (´)
  case huyen = 4   // Thanh huyền (`)
  case hoi = 8     // Thanh hỏi (ˀ)
  case nga = 16    // Thanh ngã (~)
  case nang = 32   // Thanh nặng (.)
}

/// DauMu - Dấu phụ trên nguyên âm
///
/// Nguyên âm tiếng Việt có thể có thêm dấu phụ:
/// ```
/// ┌──────────┬────────┬─────────────────────────────────┐
/// │ Dấu      │ Ký hiệu│ Chuyển đổi                      │
/// ├──────────┼────────┼─────────────────────────────────┤
/// │ khongMu  │ (không)│ a, e, o, u (nguyên âm gốc)      │
/// │ muUp     │   ^    │ a→â, e→ê, o→ô (mũ)              │
/// │ muMoc    │   ˘    │ u→ư, o→ơ (móc)                  │
/// │ muNgua   │   ˘    │ a→ă (trăng/ngựa)                │
/// └──────────┴────────┴─────────────────────────────────┘
/// ```
enum DauMu: UInt8 {
  case khongMu = 0  // Không có dấu phụ
  case muUp = 2     // Mũ (^): â, ê, ô
  case muMoc = 4    // Móc (˘): ư, ơ
  case muNgua = 8   // Trăng (˘): ă
}

// MARK: - ThanhPhanTieng (Các thành phần âm tiết)

/// ThanhPhanTieng - Các thành phần đã phân tích của âm tiết tiếng Việt
///
/// Cấu trúc âm tiết tiếng Việt: Phụ âm đầu + Nguyên âm + Phụ âm cuối
///
/// Ví dụ: "không" = "kh" + "ô" + "ng"
/// ```
/// ┌─────────────┬───────────┬─────────────┬────────────┐
/// │ phuAmDau    │ nguyenAm  │ phuAmCuoi   │ conLai     │
/// │ (đầu)       │ (giữa)    │ (cuối)      │ (phần dư)  │
/// ├─────────────┼───────────┼─────────────┼────────────┤
/// │ k, h        │ ô         │ n, g        │            │
/// └─────────────┴───────────┴─────────────┴────────────┘
/// ```
struct ThanhPhanTieng {
  /// Phụ âm đầu: b, c, ch, d, đ, g, gh, gi, h, k, kh, l, m, n, ng, ngh, nh, p, ph, qu, r, s, t, th, tr, v, x
  var phuAmDau: [Character] = []
  /// Nguyên âm: a, ă, â, e, ê, i, o, ô, ơ, u, ư, y và các nguyên âm ghép
  var nguyenAm: [Character] = []
  /// Phụ âm cuối: c, ch, m, n, ng, nh, p, t
  var phuAmCuoi: [Character] = []
  /// Phần còn lại (không thuộc âm tiết tiếng Việt hợp lệ)
  var conLai: [Character] = []

  /// Vị trí nguyên âm có dấu phụ (-1 nếu chưa đặt)
  var viTriDauMu = -1
  /// Vị trí nguyên âm có dấu thanh (-1 nếu chưa đặt)
  var viTriDauThanh = -1
  /// Cờ: chứa nguyên âm "uo" (xử lý đặc biệt dấu móc → "ươ")
  var chuaNguyenAmUO = false

  /// Kiểm tra nguyên âm có chứa ký tự chỉ định không
  func nguyenAmChua(char: Character) -> Bool {
    nguyenAm.contains(char)
  }

  /// Kiểm tra nguyên âm có chứa ít nhất một ký tự trong danh sách không
  func nguyenAmChua1KyTu(mangKyTu: [Character]) -> Bool {
    mangKyTu.contains { nguyenAm.contains($0) }
  }

  /// Kiểm tra chuỗi không phải tiếng Việt hợp lệ (chỉ có phần conLai)
  func notTiengViet() -> Bool {
    phuAmDau.isEmpty && nguyenAm.isEmpty && phuAmCuoi.isEmpty && !conLai.isEmpty
  }
}

// MARK: - TiengViet (Namespace cho hằng số)

/// TiengViet - Hằng số ngôn ngữ học và quy tắc chuyển đổi tiếng Việt
///
/// Enum này đóng vai trò namespace cho tất cả dữ liệu tĩnh được sử dụng
/// bởi engine gõ tiếng Việt, bao gồm:
/// - Bảng chữ cái (ChuCai)
/// - Bảng phụ âm (PhuAm)
/// - Bảng nguyên âm (NguyenAm)
/// - Quy tắc chuyển đổi (QuyTac)
enum TiengViet {

  // MARK: - Bảng chữ cái

  /// Chữ cái tiếng Việt thường
  static let ChuCaiThuong: [Character] = [
    "a", "b", "c", "d", "e", "g", "h", "i", "k", "l", "m", "n",
    "o", "p", "q", "r", "s", "t", "u", "v", "x", "y",
  ]

  /// Tất cả chữ cái tiếng Việt (thường + hoa)
  static let ChuCai: [Character] = ChuCaiThuong + ChuCaiThuong.map { $0.uppercased().first! }

  // MARK: - Bảng phụ âm

  /// Phụ âm đơn
  static let PhuAmDon: [String] = [
    "b", "c", "d", "g", "h", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x",
    "B", "C", "D", "G", "H", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "V", "X",
  ]

  /// Phụ âm đơn từ tiếng nước ngoài (cho từ vay mượn)
  static let PhuAmDonNuocNgoai: [String] = [
    "z", "w", "j", "f",
    "Z", "W", "J", "F",
  ]

  /// Phụ âm ghép: ch, gh, gi, kh, ng, ngh, nh, ph, qu, th, tr
  static let PhuAmGhep: [String] = [
    "ngh", "ngH", "nGh", "nGH", "Ngh", "NgH", "NGh", "NGH",
    "ch", "cH", "Ch", "CH",
    "gh", "gH", "Gh", "GH",
    "gi", "gI", "Gi", "GI",
    "kh", "kH", "Kh", "KH",
    "ng", "nG", "Ng", "NG",
    "nh", "nH", "Nh", "NH",
    "ph", "pH", "Ph", "PH",
    "qu", "qU", "Qu", "QU",
    "th", "tH", "Th", "TH",
    "tr", "tR", "Tr", "TR",
  ].sorted { $0.count > $1.count }

  /// Tất cả phụ âm đầu (phụ âm ghép trước để match đúng thứ tự ưu tiên)
  static var PhuAmDau: [String] = PhuAmGhep + PhuAmDon

  /// Phụ âm cuối hợp lệ: c, ch, m, n, ng, nh, p, t
  static let PhuAmCuoi: [String] = [
    "nh", "nH", "Nh", "NH",
    "ng", "nG", "Ng", "NG",
    "ch", "cH", "Ch", "CH",
    "m", "M",
    "n", "N",
    "c", "C",
    "p", "P",
    "t", "T",
  ].sorted { $0.count > $1.count }

  // MARK: - Bảng nguyên âm

  /// Nguyên âm đơn
  static let NguyenAmDon = [
    "a", "e", "i", "y", "o", "u",
    "A", "E", "I", "Y", "O", "U",
  ]

  /// Nguyên âm ghép - sắp xếp theo độ dài giảm dần
  static let NguyenAmGhep = [
    "IEU", "IEu", "ieu", "iEU", "iEu", "IeU", "ieU", "Ieu",
    "oaI", "oai", "oAi", "OAI", "OAi", "oAI", "OaI", "Oai",
    "uoU", "uOU", "UoU", "uOu", "uou", "UOu", "UOU", "Uou",
    "Oeo", "OEO", "OeO", "oeO", "oEO", "oEo", "OEo", "oeo",
    "OaO", "oaO", "oAo", "OAo", "Oao", "oAO", "oao", "OAO",
    "oaY", "OAy", "oAy", "Oay", "OAY", "oAY", "oay", "OaY",
    "UYA", "uya", "uYa", "UYa", "Uya", "UyA", "uyA", "uYA",
    "Uyu", "UYU", "UYu", "uyU", "UyU", "uyu", "uYu", "uYU",
    "UYE", "uye", "UyE", "UYe", "uyE", "uYe", "Uye", "uYE",
    "uOI", "UoI", "UOI", "uoI", "uOi", "Uoi", "UOi", "uoi",
    "Yeu", "YEu", "YEU", "yEu", "yEU", "yeu", "YeU", "yeU",
    "uAY", "uAy", "UaY", "UAY", "UAy", "uaY", "uay", "Uay",
    "uo", "uO", "Uo", "UO",
    "uu", "Uu", "UU", "uU",
    "uA", "ua", "UA", "Ua",
    "iA", "Ia", "IA", "ia",
    "ai", "AI", "aI", "Ai",
    "IO", "iO", "io", "Io",
    "Ao", "AO", "ao", "aO",
    "Au", "aU", "AU", "au",
    "OI", "oI", "oi", "Oi",
    "Ie", "IE", "iE", "ie",
    "ay", "Ay", "aY", "AY",
    "oa", "OA", "Oa", "oA",
    "eo", "EO", "Eo", "eO",
    "Oe", "oe", "oE", "OE",
    "Oo", "oO", "OO", "oo",
    "UI", "Ui", "ui", "uI",
    "uy", "Uy", "UY", "uY",
    "ye", "Ye", "yE", "YE",
    "Eu", "eU", "EU", "eu",
    "ue", "Ue", "uE", "UE",
    "iu", "Iu", "iU", "IU",
  ].sorted { $0.count > $1.count }

  /// Tất cả nguyên âm (nguyên âm ghép trước để match đúng thứ tự ưu tiên)
  static let NguyenAm = NguyenAmGhep + NguyenAmDon

  // MARK: - Tries for Optimization

  static let PhuAmDauTrie: Trie = {
    let trie = Trie()
    PhuAmDau.forEach { trie.insert($0) }
    return trie
  }()

  static let NguyenAmTrie: Trie = {
    let trie = Trie()
    NguyenAm.forEach { trie.insert($0) }
    return trie
  }()

  static let PhuAmCuoiTrie: Trie = {
    let trie = Trie()
    PhuAmCuoi.forEach { trie.insert($0) }
    return trie
  }()

  /// Nguyên âm chứa "uo" - cần xử lý đặc biệt khi đặt dấu móc (→ "ươ")
  static let NguyenAmUO = [
    "uo", "uO", "Uo", "UO",
    "uoU", "uOU", "UoU", "uOu", "uou", "UOu", "UOU", "Uou",
    "uOI", "UoI", "UOI", "uoI", "uOi", "Uoi", "UOi", "uoi",
  ]

  // MARK: - Quy tắc chuyển đổi

  /// Quy tắc đặt dấu thanh: nguyên âm gốc → nguyên âm có dấu thanh
  ///
  /// Ví dụ: ("a", "á") nghĩa là 'a' + thanh sắc → 'á'
  static let QuyTacDatDau: [DauThanh: [(Character, Character)]] = [
    .bang: [],
    .sac: [
      ("u", "ú"), ("ư", "ứ"), ("e", "é"), ("ê", "ế"), ("o", "ó"), ("ô", "ố"), ("ơ", "ớ"),
      ("a", "á"), ("â", "ấ"), ("ă", "ắ"), ("i", "í"), ("y", "ý"),
      ("U", "Ú"), ("Ư", "Ứ"), ("E", "É"), ("Ê", "Ế"), ("O", "Ó"), ("Ô", "Ố"), ("Ơ", "Ớ"),
      ("A", "Á"), ("Â", "Ấ"), ("Ă", "Ắ"), ("I", "Í"), ("Y", "Ý"),
    ],
    .huyen: [
      ("u", "ù"), ("ư", "ừ"), ("e", "è"), ("ê", "ề"), ("o", "ò"), ("ô", "ồ"), ("ơ", "ờ"),
      ("a", "à"), ("â", "ầ"), ("ă", "ằ"), ("i", "ì"), ("y", "ỳ"),
      ("U", "Ù"), ("Ư", "Ừ"), ("E", "È"), ("Ê", "Ề"), ("O", "Ò"), ("Ô", "Ồ"), ("Ơ", "Ờ"),
      ("A", "À"), ("Â", "Ầ"), ("Ă", "Ằ"), ("I", "Ì"), ("Y", "Ỳ"),
    ],
    .hoi: [
      ("u", "ủ"), ("ư", "ử"), ("e", "ẻ"), ("ê", "ể"), ("o", "ỏ"), ("ô", "ổ"), ("ơ", "ở"),
      ("a", "ả"), ("â", "ẩ"), ("ă", "ẳ"), ("i", "ỉ"), ("y", "ỷ"),
      ("U", "Ủ"), ("Ư", "Ử"), ("E", "Ẻ"), ("Ê", "Ể"), ("O", "Ỏ"), ("Ô", "Ổ"), ("Ơ", "Ở"),
      ("A", "Ả"), ("Â", "Ẩ"), ("Ă", "Ẳ"), ("I", "Ỉ"), ("Y", "Ỷ"),
    ],
    .nga: [
      ("u", "ũ"), ("ư", "ữ"), ("e", "ẽ"), ("ê", "ễ"), ("o", "õ"), ("ô", "ỗ"), ("ơ", "ỡ"),
      ("a", "ã"), ("â", "ẫ"), ("ă", "ẵ"), ("i", "ĩ"), ("y", "ỹ"),
      ("U", "Ũ"), ("Ư", "Ữ"), ("E", "Ẽ"), ("Ê", "Ễ"), ("O", "Õ"), ("Ô", "Ỗ"), ("Ơ", "Ỡ"),
      ("A", "Ã"), ("Â", "Ẫ"), ("Ă", "Ẵ"), ("I", "Ĩ"), ("Y", "Ỹ"),
    ],
    .nang: [
      ("u", "ụ"), ("ư", "ự"), ("e", "ẹ"), ("ê", "ệ"), ("o", "ọ"), ("ô", "ộ"), ("ơ", "ợ"),
      ("a", "ạ"), ("â", "ậ"), ("ă", "ặ"), ("i", "ị"), ("y", "ỵ"),
      ("U", "Ụ"), ("Ư", "Ự"), ("E", "Ẹ"), ("Ê", "Ệ"), ("O", "Ọ"), ("Ô", "Ộ"), ("Ơ", "Ợ"),
      ("A", "Ạ"), ("Â", "Ậ"), ("Ă", "Ặ"), ("I", "Ị"), ("Y", "Ỵ"),
    ],
  ]

  /// Quy tắc đặt dấu mũ: nguyên âm gốc → nguyên âm có dấu mũ
  ///
  /// - muUp (^): a→â, e→ê, o→ô
  /// - muMoc (móc): o→ơ, u→ư
  /// - muNgua (trăng): a→ă
  static let QuyTacDatMu: [DauMu: [(Character, Character)]] = [
    .khongMu: [],
    .muUp: [("a", "â"), ("e", "ê"), ("o", "ô"), ("A", "Â"), ("E", "Ê"), ("O", "Ô")],
    .muNgua: [("a", "ă"), ("A", "Ă")],
    .muMoc: [("o", "ơ"), ("u", "ư"), ("O", "Ơ"), ("U", "Ư")],
  ]

  /// Quy tắc gạch ngang chữ D: d → đ
  static let QuyTacGachD: [(Character, Character)] = [("d", "đ"), ("D", "Đ")]
}
