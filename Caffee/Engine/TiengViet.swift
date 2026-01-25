//
//  Vietnamese.swift
//  Caffee
//
//  Created by KhanhIceTea on 24/02/2024.
//

/// TiengViet - Mô hình âm tiết tiếng Việt (Vietnamese Syllable Model)
///
/// Cấu trúc âm tiết tiếng Việt: Phụ âm đầu + Nguyên âm + Phụ âm cuối
/// (Vietnamese syllable structure: Initial consonant + Vowel + Final consonant)
///
/// Ví dụ / Examples:
///   - "không" = "kh" + "ô" + "ng"
///   - "tiếng" = "t" + "iế" + "ng"
///   - "việt"  = "v" + "iệ" + "t"
///
/// Quy tắc đặt dấu thanh (Tone placement rules - theo chuẩn quốc gia):
///   - Âm tiết có 1 nguyên âm: đặt dấu trên nguyên âm đó
///   - Âm tiết có 2+ nguyên âm: ưu tiên nguyên âm thứ 2 nếu có phụ âm cuối hoặc 3 nguyên âm
///   - Âm tiết có dấu mũ: đặt dấu thanh trên nguyên âm có dấu mũ
///
/// Giá trị enum sử dụng power of 2 để có thể kết hợp bằng bitwise operations nếu cần.

import Foundation

// MARK: - Enums cho dấu tiếng Việt (Vietnamese Diacritics Enums)

/// DauThanh - 6 thanh điệu tiếng Việt (6 Vietnamese tones)
/// Giá trị power of 2 cho phép kết hợp bitwise nếu cần
enum DauThanh: UInt8 {
  /// Thanh ngang (không dấu) - "ma" (level tone, no mark)
  case bang = 0
  /// Thanh sắc (´) - "má" (rising tone)
  case sac = 2
  /// Thanh huyền (`) - "mà" (falling tone)
  case huyen = 4
  /// Thanh hỏi (ˀ) - "mả" (dipping-rising tone)
  case hoi = 8
  /// Thanh ngã (~) - "mã" (creaky rising tone)
  case nga = 16
  /// Thanh nặng (.) - "mạ" (low glottalized tone)
  case nang = 32
}

/// DauMu - Dấu phụ trên nguyên âm (Diacritical marks on vowels)
/// Giá trị power of 2 cho phép kết hợp bitwise nếu cần
enum DauMu: UInt8 {
  /// Không có dấu mũ - a, e, o, u (no diacritical mark)
  case khongMu = 0
  /// Mũ (^) - â, ê, ô (circumflex, pointing up)
  case muUp = 2
  /// Móc (˘) - ư, ơ (horn mark)
  case muMoc = 4
  /// Trăng (˘) - ă (breve, hình móng ngựa / horseshoe shape)
  case muNgua = 8
}

// MARK: - Thành phần âm tiết (Syllable Components)

/// ThanhPhanTieng - Cấu trúc lưu trữ các thành phần của một âm tiết tiếng Việt
/// (Structure storing components of a Vietnamese syllable)
///
/// Ví dụ phân tích "không":
///   - phuAmDau: ["k", "h"]
///   - nguyenAm: ["o"]
///   - phuAmCuoi: ["n", "g"]
struct ThanhPhanTieng {
  /// Phụ âm đầu - Initial consonant(s): b, c, ch, d, đ, g, gh, gi, h, k, kh, l, m, n, ng, ngh, nh, p, ph, qu, r, s, t, th, tr, v, x
  var phuAmDau: [Character] = []
  /// Nguyên âm - Vowel(s): a, ă, â, e, ê, i, o, ô, ơ, u, ư, y và các nguyên âm ghép
  var nguyenAm: [Character] = []
  /// Phụ âm cuối - Final consonant(s): c, ch, m, n, ng, nh, p, t
  var phuAmCuoi: [Character] = []
  /// Ký tự còn lại không thuộc âm tiết tiếng Việt hợp lệ
  var conLai: [Character] = []
  /// Vị trí nguyên âm đã đặt dấu mũ (-1 nếu chưa đặt)
  var viTriDauMu = -1
  /// Vị trí nguyên âm đã đặt dấu thanh (-1 nếu chưa đặt)
  var viTriDauThanh = -1
  /// Cờ đánh dấu có chứa nguyên âm "uo" (để xử lý đặc biệt cho dấu móc)
  var chuaNguyenAmUO = false

  /// Kiểm tra nguyên âm có chứa ký tự chỉ định không
  func nguyenAmChua(char: Character) -> Bool {
    return nguyenAm.contains(char)
  }

  /// Kiểm tra nguyên âm có chứa ít nhất một ký tự trong danh sách không
  func nguyenAmChua1KyTu(mangKyTu: [Character]) -> Bool {
    for c in mangKyTu {
      if nguyenAm.contains(c) {
        return true
      }
    }
    return false
  }

  /// Kiểm tra chuỗi không phải tiếng Việt hợp lệ (chỉ có phần conLai)
  func notTiengViet() -> Bool {
    return phuAmDau.isEmpty && nguyenAm.isEmpty && phuAmCuoi.isEmpty && !conLai.isEmpty
  }
}

// MARK: - TiengViet Class

/// TiengViet - Lớp chính xử lý biến đổi âm tiết tiếng Việt
/// (Main class for Vietnamese syllable transformation)
class TiengViet {

  // MARK: - Bảng chữ cái (Alphabet Tables)

  /// Chữ cái tiếng Việt thường (lowercase Vietnamese letters)
  static let ChuCaiThuong: [Character] = [
    "a", "b", "c", "d", "e", "g", "h", "i", "k", "l", "m", "n",
    "o", "p", "q", "r", "s", "t", "u", "ư", "v", "x", "y",
  ]
  /// Chữ cái tiếng Việt (cả thường và hoa)
  static let ChuCai: [Character] = ChuCaiThuong + ChuCaiThuong.map { $0.uppercased().first! }

  // MARK: - Bảng phụ âm (Consonant Tables)

  /// Phụ âm đơn tiếng Việt (Single consonants)
  static let PhuAmDon: [String] = [
    "b", "c", "d", "g", "h", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x",
    "B", "C", "D", "G", "H", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "V", "X",
  ]
  /// Phụ âm đơn từ tiếng nước ngoài (Foreign single consonants)
  static let PhuAmDonNuocNgoai: [String] = [
    "z", "w", "j", "f",
    "Z", "W", "J", "F",
  ]
  /// Phụ âm ghép (Consonant clusters)
  /// Bao gồm: ch, gh, gi, kh, ng, ngh, nh, ph, qu, th, tr
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
  ]
  /// Tất cả phụ âm đầu (ưu tiên phụ âm ghép trước để match đúng)
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
  ]

  // MARK: - Bảng nguyên âm (Vowel Tables)

  /// Nguyên âm đơn (Single vowels)
  static let NguyenAmDon = [
    "a", "e", "i", "y", "o", "u",
    "A", "E", "I", "Y", "O", "U",
  ]

  /// Nguyên âm ghép (Vowel clusters) - sắp xếp theo độ dài giảm dần
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
  ]
  /// Tất cả nguyên âm (ưu tiên nguyên âm ghép trước để match đúng)
  static let NguyenAm = NguyenAmGhep + NguyenAmDon
  /// Nguyên âm có chứa "uo" - cần xử lý đặc biệt khi đặt dấu móc (ươ)
  static let NguyenAmUO = [
    "uo", "uO", "Uo", "UO",
    "uoU", "uOU", "UoU", "uOu", "uou", "UOu", "UOU", "Uou",
    "uOI", "UoI", "UOI", "uoI", "uOi", "Uoi", "UOi", "uoi",
  ]

  // MARK: - Quy tắc chuyển đổi ký tự (Character Transformation Rules)

  /// Quy tắc đặt dấu thanh: ánh xạ từ nguyên âm không dấu → nguyên âm có dấu thanh
  /// (Tone mark rules: mapping from unmarked vowel → toned vowel)
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

  /// Quy tắc đặt dấu mũ: ánh xạ từ nguyên âm gốc → nguyên âm có dấu mũ
  /// (Diacritical mark rules: mapping from base vowel → marked vowel)
  /// - muUp (^): a→â, e→ê, o→ô
  /// - muMoc (horn): o→ơ, u→ư
  /// - muNgua (breve): a→ă
  static let QuyTacDatMu: [DauMu: [(Character, Character)]] = [
    .khongMu: [],
    .muUp: [("a", "â"), ("e", "ê"), ("o", "ô"), ("A", "Â"), ("E", "Ê"), ("O", "Ô")],
    .muNgua: [("a", "ă"), ("A", "Ă")],
    .muMoc: [("o", "ơ"), ("u", "ư"), ("O", "Ơ"), ("U", "Ư")],
  ]

  /// Quy tắc gạch ngang chữ D: d → đ
  static let QuyTacGachD: [(Character, Character)] = [("d", "đ"), ("D", "Đ")]

  // MARK: - Properties

  /// Chuỗi ký tự gốc chưa có dấu (đầu vào từ bàn phím)
  var chuKhongDau: [Character] = []
  /// Dấu thanh hiện tại đang áp dụng
  var dauThanh: DauThanh = .bang
  /// Dấu mũ hiện tại đang áp dụng
  var dauMu: DauMu = .khongMu
  /// Cờ đánh dấu có gạch ngang chữ D (d → đ)
  var gachD: Bool = false

  /// Kết quả phân tích âm tiết
  var thanhPhanTieng: ThanhPhanTieng = ThanhPhanTieng()
  /// Chuỗi kết quả sau khi biến đổi
  var transformed = ""

  // MARK: - Debug

  /// Trả về trạng thái hiện tại để debug
  public func debug() -> (ThanhPhanTieng, DauMu, DauThanh, Bool) {
    return (thanhPhanTieng, dauMu, dauThanh, gachD)
  }

  // MARK: - Public API

  /// Thêm ký tự vào chuỗi đầu vào và phân tích lại
  public func push(letter: Character) {
    chuKhongDau.append(letter)
    parse()
  }

  /// Xóa ký tự cuối cùng và phân tích lại
  public func pop() -> Character? {
    let popped = chuKhongDau.popLast()
    parse()
    return popped
  }

  /// Đặt/xóa dấu mũ (toggle: gõ lần 2 sẽ xóa dấu)
  public func datMu(dauMuMoi: DauMu) {
    dauMu = dauMu == dauMuMoi ? .khongMu : dauMuMoi
    parse()
  }

  /// Đặt/xóa dấu thanh (toggle: gõ lần 2 sẽ xóa dấu)
  public func datDauThanh(dauThanhMoi: DauThanh) {
    dauThanh = dauThanh == dauThanhMoi ? .bang : dauThanhMoi
    parse()
  }

  /// Đặt/xóa gạch ngang chữ D (toggle: dd → đ, đd → d)
  public func datGachD() {
    gachD = !gachD
    parse()
  }

  // MARK: - Phân tích âm tiết (Syllable Parsing)

  /// Phân tích chuỗi đầu vào thành các thành phần âm tiết
  /// Quy trình: tách phụ âm đầu → nguyên âm → phụ âm cuối → phần còn lại
  public func parse() {
    var strKhongDau = String(chuKhongDau)
    thanhPhanTieng.phuAmDau = []
    thanhPhanTieng.nguyenAm = []
    thanhPhanTieng.phuAmCuoi = []
    thanhPhanTieng.conLai = []

    if !isBlank() {
      // Bước 1: Tách phụ âm đầu
      for phuAmDau in TiengViet.PhuAmDau {
        if strKhongDau.starts(with: phuAmDau) {
          thanhPhanTieng.phuAmDau = Array(phuAmDau)
          strKhongDau = String(strKhongDau.dropFirst(phuAmDau.count))
          break
        }
      }

      // Bước 2: Tách nguyên âm
      for nguyenAm in TiengViet.NguyenAm {
        if strKhongDau.starts(with: nguyenAm) {
          thanhPhanTieng.nguyenAm = Array(nguyenAm)
          thanhPhanTieng.chuaNguyenAmUO = TiengViet.NguyenAmUO.contains(nguyenAm)
          strKhongDau = String(strKhongDau.dropFirst(nguyenAm.count))
          break
        }
      }

      // Bước 3: Tách phụ âm cuối
      for phuAmCuoi in TiengViet.PhuAmCuoi {
        if strKhongDau.starts(with: phuAmCuoi) {
          thanhPhanTieng.phuAmCuoi = Array(phuAmCuoi)
          strKhongDau = String(strKhongDau.dropFirst(phuAmCuoi.count))
          break
        }
      }

      // Bước 4: Phần còn lại (không thuộc âm tiết tiếng Việt hợp lệ)
      thanhPhanTieng.conLai = Array(strKhongDau)
    }

    // Xóa dấu mũ, dấu thanh nếu vị trí đặt tại nguyên âm đã bị xóa
    if thanhPhanTieng.viTriDauMu >= thanhPhanTieng.nguyenAm.count {
      thanhPhanTieng.viTriDauMu = -1
      dauMu = .khongMu
    }
    if thanhPhanTieng.viTriDauThanh >= thanhPhanTieng.nguyenAm.count {
      thanhPhanTieng.viTriDauThanh = -1
      dauThanh = .bang
    }

    // Trường hợp đặc biệt: "gi" đứng một mình, không có nguyên âm theo sau
    // → chữ "i" trong "gi" trở thành nguyên âm (ví dụ: gì, gỉ, gĩ)
    if thanhPhanTieng.nguyenAm.count == 0 && String(thanhPhanTieng.phuAmDau).lowercased() == "gi" {
      thanhPhanTieng.nguyenAm.append(thanhPhanTieng.phuAmDau.popLast()!)
    }
  }

  // MARK: - Helper Methods

  /// Chuyển đổi ký tự theo quy tắc cho trước
  /// - Parameters:
  ///   - kytu: Ký tự cần chuyển đổi
  ///   - quyTac: Bảng ánh xạ (ký tự gốc, ký tự mới)
  /// - Returns: Ký tự mới nếu tìm thấy trong bảng, nil nếu không
  public func chuyenKyTu(kytu: Character, quyTac: [(Character, Character)]) -> Character? {
    for (match, to) in quyTac {
      if match == kytu {
        return to
      }
    }
    return nil
  }

  /// Kiểm tra chuỗi đầu vào có rỗng không
  public func isBlank() -> Bool {
    return chuKhongDau.isEmpty
  }

  // MARK: - Chuyển đổi (Transformation)

  /// Biến đổi chuỗi đầu vào thành chuỗi tiếng Việt có dấu
  ///
  /// Quy trình biến đổi:
  /// 1. Clone thành phần tiếng để không ảnh hưởng bản gốc
  /// 2. Áp dụng gạch ngang D nếu có (d → đ)
  /// 3. Áp dụng dấu mũ vào nguyên âm phù hợp
  /// 4. Áp dụng dấu thanh vào nguyên âm phù hợp
  /// 5. Ghép các thành phần lại thành chuỗi kết quả
  public func transform() -> String {
    // Clone để không ảnh hưởng bản gốc
    var tieng = thanhPhanTieng
    let countNguyenAm = tieng.nguyenAm.count

    if isBlank() {
      return ""
    }

    // Bước 1: Áp dụng gạch ngang D (d → đ)
    apDungGachD(vaoTieng: &tieng)

    // Bước 2: Áp dụng dấu mũ
    apDungDauMu(vaoTieng: &tieng, soNguyenAm: countNguyenAm)

    // Bước 3: Áp dụng dấu thanh
    apDungDauThanh(vaoTieng: &tieng, soNguyenAm: countNguyenAm)

    // Lưu vị trí dấu để sử dụng sau
    thanhPhanTieng.viTriDauMu = tieng.viTriDauMu
    thanhPhanTieng.viTriDauThanh = tieng.viTriDauThanh

    return String(tieng.phuAmDau + tieng.nguyenAm + tieng.phuAmCuoi + tieng.conLai)
  }

  // MARK: - Quy tắc đặt dấu (Tone Placement Rules)

  /// Áp dụng gạch ngang D vào phụ âm đầu (d → đ)
  private func apDungGachD(vaoTieng tieng: inout ThanhPhanTieng) {
    if gachD,
      let kyTuPhuAmDau = tieng.phuAmDau.first,
      let kyTuMoi = chuyenKyTu(kytu: kyTuPhuAmDau, quyTac: TiengViet.QuyTacGachD)
    {
      tieng.phuAmDau[0] = kyTuMoi
    }
  }

  /// Áp dụng dấu mũ vào nguyên âm theo quy tắc
  ///
  /// Quy tắc đặt dấu mũ:
  /// - Trường hợp đặc biệt "uo" + dấu móc → "ươ" (cả 2 nguyên âm đều có dấu)
  /// - Có 3 nguyên âm hoặc 2 nguyên âm + phụ âm cuối: đặt ở nguyên âm thứ 2
  /// - Còn lại: đặt ở nguyên âm đầu tiên có thể nhận dấu
  private func apDungDauMu(vaoTieng tieng: inout ThanhPhanTieng, soNguyenAm: Int) {
    guard let quyTac = TiengViet.QuyTacDatMu[dauMu], !quyTac.isEmpty else { return }

    // Nested function có thể capture inout parameter
    func thuDatDauMu(_ idx: Int) -> Bool {
      if let kyTuMoi = chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
        tieng.nguyenAm[idx] = kyTuMoi
        tieng.viTriDauMu = idx
        return true
      }
      return false
    }

    let datDauMocUO = (dauMu == .muMoc) && tieng.chuaNguyenAmUO

    if datDauMocUO && thuDatDauMu(1) {
      if soNguyenAm == 3 || !tieng.phuAmCuoi.isEmpty,
        let dauU = chuyenKyTu(kytu: tieng.nguyenAm[0], quyTac: quyTac)
      {
        tieng.nguyenAm[0] = dauU
      }
    } else if (soNguyenAm == 3 || (soNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty)) && thuDatDauMu(1) {
      // Đặt ở nguyên âm thứ 2 thành công
    } else {
      for i in 0..<soNguyenAm {
        if thuDatDauMu(i) { break }
      }
    }
  }

  /// Áp dụng dấu thanh vào nguyên âm theo quy tắc
  ///
  /// Quy tắc đặt dấu thanh:
  /// - Ưu tiên 1: Đặt trên nguyên âm đã có dấu mũ (nếu có)
  /// - Ưu tiên 2: Có 3 nguyên âm hoặc 2 nguyên âm + phụ âm cuối → đặt ở nguyên âm thứ 2
  /// - Còn lại: Đặt ở nguyên âm đầu tiên có thể nhận dấu
  private func apDungDauThanh(vaoTieng tieng: inout ThanhPhanTieng, soNguyenAm: Int) {
    guard let quyTac = TiengViet.QuyTacDatDau[dauThanh], !quyTac.isEmpty else { return }

    // Nested function có thể capture inout parameter
    func thuDatDauThanh(_ idx: Int) -> Bool {
      if let kyTuMoi = chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
        tieng.nguyenAm[idx] = kyTuMoi
        tieng.viTriDauThanh = idx
        return true
      }
      return false
    }

    if tieng.viTriDauMu > -1 && thuDatDauThanh(tieng.viTriDauMu) {
      return
    }
    if (soNguyenAm == 3 || (soNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty)) && thuDatDauThanh(1) {
      return
    }
    for i in 0..<soNguyenAm {
      if thuDatDauThanh(i) { break }
    }
  }
}
