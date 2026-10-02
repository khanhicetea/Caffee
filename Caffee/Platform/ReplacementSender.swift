//
//  ReplacementSender.swift
//  Caffee
//

import Foundation

/// Text edit that turns what is on screen into the transformed word: delete `deleteCount`
/// characters, then insert `insert`.
struct Replacement: Equatable {
  let deleteCount: Int
  let insert: [Character]

  static let none = Replacement(deleteCount: 0, insert: [])

  var isEmpty: Bool { deleteCount == 0 && insert.isEmpty }

  /// Smallest edit (common prefix kept) that turns `from` into `to`.
  static func diff(from: String, to: String) -> Replacement {
    let fromChars = Array(from)
    let toChars = Array(to)
    var commonPrefixLength = 0
    let minLength = min(fromChars.count, toChars.count)

    while commonPrefixLength < minLength
      && fromChars[commonPrefixLength] == toChars[commonPrefixLength]
    {
      commonPrefixLength += 1
    }

    return Replacement(
      deleteCount: fromChars.count - commonPrefixLength,
      insert: Array(toChars.dropFirst(commonPrefixLength)))
  }
}

protocol ReplacementSender {
  func sendReplacement(_ replacement: Replacement, strategy: SendingStrategy)

  /// Like `sendReplacement`, but selects `deleteCount` characters to the left (Shift+Left)
  /// instead of deleting them, so inline autocomplete text is replaced too.
  func sendSelectAndReplace(_ replacement: Replacement, strategy: SendingStrategy)
}
