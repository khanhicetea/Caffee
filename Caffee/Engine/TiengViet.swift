//
//  Vietnamese.swift
//  Caffee
//
//  Created by KhanhIceTea on 24/02/2024.
//

import Foundation

enum DauThanh: UInt8 {
  case bang = 0
  case sac = 2
  case huyen = 4
  case hoi = 8
  case nga = 16
  case nang = 32
}

enum DauMu: UInt8 {
  case khongMu = 0
  case muUp = 2
  case muMoc = 4
  case muNgua = 8
}

struct ThanhPhanTieng {
  var phuAmDau: [Character] = []
  var nguyenAm: [Character] = []
  var phuAmCuoi: [Character] = []
  var conLai: [Character] = []
  var viTriDauMu = -1
  var viTriDauThanh = -1
  var chuaNguyenAmUO = false

  func nguyenAmChua(char: Character) -> Bool {
    return nguyenAm.contains(char)
  }

  func nguyenAmChua1KyTu(mangKyTu: [Character]) -> Bool {
    for c in mangKyTu {
      if nguyenAm.contains(c) {
        return true
      }
    }
    return false
  }

  func notTiengViet() -> Bool {
    return phuAmDau.isEmpty && nguyenAm.isEmpty && phuAmCuoi.isEmpty && !conLai.isEmpty
  }
}

class TiengViet {
  static let ChuCaiThuong: [Character] = [
    "a", "b", "c", "d", "e", "g", "h", "i", "k", "l", "m", "n",
    "o", "p", "q", "r", "s", "t", "u", "ư", "v", "x", "y",
  ]
  static let ChuCai: [Character] = ChuCaiThuong + ChuCaiThuong.map { $0.uppercased().first! }

  static let PhuAmDon: [String] = [
    "b", "c", "d", "g", "h", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "x",
    "B", "C", "D", "G", "H", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "V", "X",
  ]
  static let PhuAmDonNuocNgoai: [String] = [
    "z", "w", "j", "f",
    "Z", "W", "J", "F",
  ]
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
  static var PhuAmDau: [String] = PhuAmGhep + PhuAmDon
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

  static let NguyenAmDon = [
    "a", "e", "i", "y", "o", "u",
    "A", "E", "I", "Y", "O", "U",
  ]

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
  static let NguyenAm = NguyenAmGhep + NguyenAmDon
  static let NguyenAmUO = [
    "uo", "uO", "Uo", "UO",
    "uoU", "uOU", "UoU", "uOu", "uou", "UOu", "UOU", "Uou",
    "uOI", "UoI", "UOI", "uoI", "uOi", "Uoi", "UOi", "uoi",
  ]

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

  static let QuyTacDatMu: [DauMu: [(Character, Character)]] = [
    .khongMu: [],
    .muUp: [("a", "â"), ("e", "ê"), ("o", "ô"), ("A", "Â"), ("E", "Ê"), ("O", "Ô")],
    .muNgua: [("a", "ă"), ("A", "Ă")],
    .muMoc: [("o", "ơ"), ("u", "ư"), ("O", "Ơ"), ("U", "Ư")],
  ]

  static let QuyTacGachD: [(Character, Character)] = [("d", "đ"), ("D", "Đ")]

  var chuKhongDau: [Character] = []
  var dauThanh: DauThanh = .bang
  var dauMu: DauMu = .khongMu
  var gachD: Bool = false

  var thanhPhanTieng: ThanhPhanTieng = ThanhPhanTieng()
  var transformed = ""

  public func debug() -> (ThanhPhanTieng, DauMu, DauThanh, Bool) {
    return (thanhPhanTieng, dauMu, dauThanh, gachD)
  }

  public func push(letter: Character) {
    chuKhongDau.append(letter)
    parse()
  }

  public func pop() -> Character? {
    let popped = chuKhongDau.popLast()
    parse()
    return popped
  }

  public func datMu(dauMuMoi: DauMu) {
    dauMu = dauMu == dauMuMoi ? .khongMu : dauMuMoi
    parse()
  }

  public func datDauThanh(dauThanhMoi: DauThanh) {
    dauThanh = dauThanh == dauThanhMoi ? .bang : dauThanhMoi
    parse()
  }

  public func datGachD() {
    gachD = !gachD
    parse()
  }

  public func parse() {
    var strKhongDau = String(chuKhongDau)
    thanhPhanTieng.phuAmDau = []
    thanhPhanTieng.nguyenAm = []
    thanhPhanTieng.phuAmCuoi = []
    thanhPhanTieng.conLai = []

    if !isBlank() {
      for phuAmDau in TiengViet.PhuAmDau {
        if strKhongDau.starts(with: phuAmDau) {
          thanhPhanTieng.phuAmDau = Array(phuAmDau)
          strKhongDau = String(strKhongDau.dropFirst(phuAmDau.count))
          break
        }
      }

      for nguyenAm in TiengViet.NguyenAm {
        if strKhongDau.starts(with: nguyenAm) {
          thanhPhanTieng.nguyenAm = Array(nguyenAm)
          thanhPhanTieng.chuaNguyenAmUO = TiengViet.NguyenAmUO.contains(nguyenAm)
          strKhongDau = String(strKhongDau.dropFirst(nguyenAm.count))
          break
        }
      }

      for phuAmCuoi in TiengViet.PhuAmCuoi {
        if strKhongDau.starts(with: phuAmCuoi) {
          thanhPhanTieng.phuAmCuoi = Array(phuAmCuoi)
          strKhongDau = String(strKhongDau.dropFirst(phuAmCuoi.count))
          break
        }
      }

      thanhPhanTieng.conLai = Array(strKhongDau)
    }

    // Xoa dau mu, dau thanh neu vi tri dat tai nguyen am da bi xoa
    if thanhPhanTieng.viTriDauMu >= thanhPhanTieng.nguyenAm.count {
      thanhPhanTieng.viTriDauMu = -1
      dauMu = .khongMu
    }
    if thanhPhanTieng.viTriDauThanh >= thanhPhanTieng.nguyenAm.count {
      thanhPhanTieng.viTriDauThanh = -1
      dauThanh = .bang
    }

    // TH dac biet : GI 1 minh, khong co nguyen am
    if thanhPhanTieng.nguyenAm.count == 0 && String(thanhPhanTieng.phuAmDau).lowercased() == "gi" {
      thanhPhanTieng.nguyenAm.append(thanhPhanTieng.phuAmDau.popLast()!)
    }
  }

  public func chuyenKyTu(kytu: Character, quyTac: [(Character, Character)]) -> Character? {
    for (match, to) in quyTac {
      if match == kytu {
        return to
      }
    }
    return nil
  }

  public func isBlank() -> Bool {
    return chuKhongDau.isEmpty
  }

  public func transform() -> String {
    // Clone to modified
    var tieng = thanhPhanTieng
    let countNguyenAm = tieng.nguyenAm.count

    if isBlank() {
      return ""
    }

    if gachD,
      let kyTuPhuAmDau = tieng.phuAmDau.first,
      let kyTuMoi = chuyenKyTu(kytu: kyTuPhuAmDau, quyTac: TiengViet.QuyTacGachD)
    {
      tieng.phuAmDau[0] = kyTuMoi
    }

    if let quyTac = TiengViet.QuyTacDatMu[dauMu], !quyTac.isEmpty {
      let thuDatDauMu: (Int) -> Bool = { (idx) in
        if let kyTuMoi = self.chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
          tieng.nguyenAm[idx] = kyTuMoi
          tieng.viTriDauMu = idx
          return true
        }
        return false
      }
      let datDauMocUO = (dauMu == .muMoc) && tieng.chuaNguyenAmUO

      if datDauMocUO && thuDatDauMu(1) {
        if countNguyenAm == 3 || !tieng.phuAmCuoi.isEmpty,
          let dauU = chuyenKyTu(kytu: tieng.nguyenAm[0], quyTac: quyTac)
        {
          tieng.nguyenAm[0] = dauU
        }
      } else if (countNguyenAm == 3 || (countNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty))
        && thuDatDauMu(1)
      {
        // ok
      } else {
        for i in 0..<countNguyenAm {
          if thuDatDauMu(i) { break }
        }
      }
    }

    if let quyTac = TiengViet.QuyTacDatDau[dauThanh], !quyTac.isEmpty {
      let thuDatDauThanh: (Int) -> Bool = { (idx) in
        if let kyTuMoi = self.chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
          tieng.nguyenAm[idx] = kyTuMoi
          tieng.viTriDauThanh = idx
          return true
        }
        return false
      }

      if tieng.viTriDauMu > -1 && thuDatDauThanh(tieng.viTriDauMu) {
        // ok
      } else if (countNguyenAm == 3 || (countNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty))
        && thuDatDauThanh(1)
      {
        // ok
      } else {
        for i in 0..<countNguyenAm {
          if thuDatDauThanh(i) { break }
        }
      }
    }

    // Store for later
    thanhPhanTieng.viTriDauMu = tieng.viTriDauMu
    thanhPhanTieng.viTriDauThanh = tieng.viTriDauThanh

    return String(tieng.phuAmDau + tieng.nguyenAm + tieng.phuAmCuoi + tieng.conLai)
  }
}
