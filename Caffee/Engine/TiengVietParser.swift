//
//  TiengVietParser.swift
//  Caffee
//
//  Pure parsing functions for Vietnamese syllables
//

import Foundation

/// TiengVietParser - Pure parsing functions with no side effects
enum TiengVietParser {

  /// Parse a sequence of characters into Vietnamese syllable components
  /// - Parameter chuKhongDau: Array of characters without diacritics
  /// - Returns: ThanhPhanTieng with parsed components
  static func parse(_ chuKhongDau: [Character]) -> ThanhPhanTieng {
    var result = ThanhPhanTieng()
    var remaining = String(chuKhongDau)

    guard !remaining.isEmpty else { return result }

    // Step 1: Match initial consonant
    for phuAmDau in TiengViet.PhuAmDau {
      if remaining.hasPrefix(phuAmDau) {
        let matched = String(remaining.prefix(phuAmDau.count))

        // Special case: "gi" handling
        // When "gi" is matched, we need to check if there's a following vowel
        if matched.lowercased() == "gi" {
          let afterGi = String(remaining.dropFirst(2))
          let hasFollowingVowel = TiengViet.NguyenAm.contains { vowel in
            afterGi.lowercased().hasPrefix(vowel.lowercased())
          }

          if hasFollowingVowel {
            // "gia", "giet" -> "gi" is consonant, continue parsing vowel
            result.phuAmDau = Array(matched)
            remaining = afterGi
          } else {
            // "gi" alone (e.g., "gi" in "gi" -> "gi") -> "g" is consonant, "i" is vowel
            result.phuAmDau = [matched.first!]
            result.nguyenAm = [matched.last!]
            remaining = afterGi
            // Skip vowel matching since we already have it, continue to final consonant
            return finishParsing(result: &result, remaining: remaining, skipVowel: true)
          }
        } else {
          result.phuAmDau = Array(matched)
          remaining = String(remaining.dropFirst(phuAmDau.count))
        }
        break
      }
    }

    // Continue with vowel, final consonant, remainder
    return finishParsing(result: &result, remaining: remaining, skipVowel: false)
  }

  /// Continue parsing after initial consonant has been matched
  private static func finishParsing(result: inout ThanhPhanTieng, remaining: String, skipVowel: Bool) -> ThanhPhanTieng {
    var remaining = remaining

    // Match vowel (if not already set by "gi" case)
    if !skipVowel {
      for nguyenAm in TiengViet.NguyenAm {
        if remaining.hasPrefix(nguyenAm) {
          let matched = String(remaining.prefix(nguyenAm.count))
          result.nguyenAm = Array(matched)
          result.chuaNguyenAmUO = TiengViet.NguyenAmUO.contains {
            $0.lowercased() == nguyenAm.lowercased()
          }
          remaining = String(remaining.dropFirst(nguyenAm.count))
          break
        }
      }
    }

    // Match final consonant
    for phuAmCuoi in TiengViet.PhuAmCuoi {
      if remaining.hasPrefix(phuAmCuoi) {
        let matched = String(remaining.prefix(phuAmCuoi.count))
        result.phuAmCuoi = Array(matched)
        remaining = String(remaining.dropFirst(phuAmCuoi.count))
        break
      }
    }

    // Remainder (characters that don't fit Vietnamese syllable pattern)
    result.conLai = Array(remaining)
    return result
  }
}
