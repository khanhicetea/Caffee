//
//  TiengVietValidator.swift
//  Caffee
//
//  Validates Vietnamese syllable structure and detects invalid combinations
//

import Foundation

/// TiengVietValidator - Validates Vietnamese syllable structure
/// Detects when user input cannot form a valid Vietnamese syllable,
/// triggering recovery to original input
enum TiengVietValidator {

  // MARK: - Valid Vietnamese Phonotactics

  /// Valid final consonants (phụ âm cuối) in Vietnamese
  /// Only these consonants can appear at the end of a Vietnamese syllable
  static let ValidPhuAmCuoi: Set<String> = [
    "c", "ch", "m", "n", "ng", "nh", "p", "t",
  ]

  /// Valid vowel + final consonant combinations
  /// Key: vowel (lowercase), Value: set of valid final consonants
  /// Based on Vietnamese phonotactics rules
  ///
  /// Note: Most compound vowels (ai, ao, au, ay, âu, ây, eo, êu, oi, ôi, ơi, ui, ưi, ưu, etc.)
  /// do NOT take final consonants - they are complete syllable nuclei on their own.
  static let ValidVowelEndings: [String: Set<String>] = [
    // Simple vowels - can take various final consonants
    "a": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],
    "ă": ["c", "m", "n", "ng", "p", "t"],
    "â": ["c", "m", "n", "ng", "p", "t"],
    "e": ["c", "m", "n", "p", "t"],
    "ê": ["ch", "m", "n", "nh", "p", "t"],
    "i": ["ch", "m", "n", "nh", "p", "t"],
    "o": ["c", "m", "n", "ng", "p", "t"],
    "ô": ["c", "m", "n", "ng", "p", "t"],
    "ơ": ["m", "n", "p", "t"],
    "u": ["c", "m", "n", "ng", "p", "t"],
    "ư": ["c", "m", "n", "ng", "p", "t"],
    "y": ["ch", "m", "n", "nh", "p", "t"],

    // Compound vowels that CAN take final consonants
    // iê/ie - tiếng, biết, kiếm, điện, etc.
    "iê": ["c", "m", "n", "ng", "p", "t"],
    "ie": ["c", "m", "n", "ng", "p", "t"],

    // uô - cuốc, muốn, buồng, etc.
    "uô": ["c", "m", "n", "ng", "p", "t"],
    "uo": ["c", "m", "n", "ng", "p", "t"],

    // ươ - lướt, mượn, hương, etc.
    "ươ": ["c", "m", "n", "ng", "p", "t"],

    // oa - hoạch, toàn, khoang, loan, etc.
    "oa": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],

    // oă - xoắn, loắt, etc.
    "oă": ["c", "m", "n", "ng", "p", "t"],

    // uâ - luật, xuân, etc.
    "uâ": ["n", "t"],

    // uê - huệch, tuềnh, etc. (rare)
    "uê": ["ch", "nh"],

    // uy - huynh, quýt, etc.
    "uy": ["ch", "n", "nh", "p", "t"],

    // yê - yến, yêm, etc.
    "yê": ["m", "n", "p", "t"],
    "ye": ["m", "n", "p", "t"],

    // Compound vowels that do NOT take final consonants (empty set)
    // These are complete on their own: ai, ao, au, ay, âu, ây, eo, êu, ia, iu, oi, ôi, ơi, ua, ui, ưa, ưi, ươi, ưu
    "ai": [],
    "ao": [],
    "au": [],
    "ay": [],
    "âu": [],
    "ây": [],
    "eo": [],
    "êu": [],
    "ia": [],
    "iu": [],
    "oi": [],
    "ôi": [],
    "ơi": [],
    "ua": [],
    "ui": [],
    "ưa": [],
    "ưi": [],
    "ươi": [],
    "ưu": [],
  ]

  /// Invalid vowel combinations that cannot exist in Vietnamese
  /// These are sequences that should trigger immediate recovery
  static let InvalidVowelCombinations: Set<String> = [
    "ae", "ea", "ey", "iy", "oe", "uu", "yi", "yo", "yu",
  ]

  // MARK: - Validation Methods

  /// Check if the parsed syllable needs recovery (is invalid Vietnamese)
  /// - Parameters:
  ///   - thanhPhan: The parsed syllable components
  ///   - dauMu: The current diacritical mark (circumflex, horn, breve)
  /// - Returns: true if the syllable is invalid and needs recovery
  static func needsRecovery(_ thanhPhan: ThanhPhanTieng, dauMu: DauMu = .khongMu) -> Bool {
    // Case 1: Has leftover characters (conLai) that don't fit Vietnamese pattern
    if !thanhPhan.conLai.isEmpty {
      return true
    }

    // Case 2: Check for invalid vowel combinations
    let nguyenAm = String(thanhPhan.nguyenAm).lowercased()
    if InvalidVowelCombinations.contains(nguyenAm) {
      return true
    }

    // Case 3: Validate vowel + final consonant combination
    if !thanhPhan.phuAmCuoi.isEmpty {
      let phuAmCuoi = String(thanhPhan.phuAmCuoi).lowercased()

      // First check if it's a valid final consonant at all
      if !ValidPhuAmCuoi.contains(phuAmCuoi) {
        return true
      }

      // Then check if this vowel can have this final consonant
      // We need to consider the transformed vowel with diacritics, not just the base vowel
      // For example: "ua" cannot take final consonant, but "uâ" can take "n" or "t"
      if !isValidVowelEnding(nguyenAm: nguyenAm, phuAmCuoi: phuAmCuoi, dauMu: dauMu) {
        return true
      }
    }

    return false
  }

  /// Validate if a vowel can have a specific final consonant
  /// - Parameters:
  ///   - nguyenAm: The vowel (lowercase, base form without diacritics)
  ///   - phuAmCuoi: The final consonant (lowercase)
  ///   - dauMu: The diacritical mark being applied
  /// - Returns: true if the combination is valid
  private static func isValidVowelEnding(nguyenAm: String, phuAmCuoi: String, dauMu: DauMu) -> Bool {
    // First, transform the vowel with the diacritical mark to check the actual vowel
    // This is crucial because some base vowels (like "ua") can't take final consonants,
    // but their transformed versions (like "uâ") can.
    let transformedVowel = transformVowelWithMu(nguyenAm: nguyenAm, dauMu: dauMu)
    
    // Check the transformed vowel first
    if let validEndings = ValidVowelEndings[transformedVowel] {
      return validEndings.contains(phuAmCuoi)
    }
    
    // If no specific rules for transformed vowel, check base vowel
    if let validEndings = ValidVowelEndings[nguyenAm] {
      return validEndings.contains(phuAmCuoi)
    }

    // For vowels not in our dictionary, allow all standard final consonants
    // This is a conservative approach - better to allow than to incorrectly reject
    return ValidPhuAmCuoi.contains(phuAmCuoi)
  }
  
  /// Transform a base vowel to its form with diacritical mark applied
  /// - Parameters:
  ///   - nguyenAm: The base vowel (lowercase)
  ///   - dauMu: The diacritical mark to apply
  /// - Returns: The transformed vowel string
  private static func transformVowelWithMu(nguyenAm: String, dauMu: DauMu) -> String {
    switch dauMu {
    case .khongMu:
      return nguyenAm
    case .muUp:  // Circumflex: a→â, e→ê, o→ô
      var result = nguyenAm
      result = result.replacingOccurrences(of: "a", with: "â")
      result = result.replacingOccurrences(of: "e", with: "ê")
      result = result.replacingOccurrences(of: "o", with: "ô")
      return result
    case .muMoc:  // Horn: o→ơ, u→ư
      var result = nguyenAm
      result = result.replacingOccurrences(of: "o", with: "ơ")
      result = result.replacingOccurrences(of: "u", with: "ư")
      return result
    case .muNgua:  // Breve: a→ă
      return nguyenAm.replacingOccurrences(of: "a", with: "ă")
    }
  }
}
