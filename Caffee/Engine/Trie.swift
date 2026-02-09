//
//  Trie.swift
//  Caffee
//
//  Data structure for fast prefix matching
//

import Foundation

class TrieNode {
  var children: [Character: TrieNode] = [:]
  var isEndOfWord: Bool = false
  // Store the actual matched string for convenience
  var value: String?
}

class Trie {
  private let root = TrieNode()

  /// Insert a string into the Trie
  func insert(_ word: String) {
    var current = root
    for char in word {
      if current.children[char] == nil {
        current.children[char] = TrieNode()
      }
      current = current.children[char]!
    }
    current.isEndOfWord = true
    current.value = word
  }

  /// Find the longest prefix of a string that exists in the Trie
  /// - Parameter text: The string to search in
  /// - Returns: The longest matching prefix found
  func findLongestPrefix(in text: String) -> String? {
    var current = root
    var longestMatch: String?
    
    for char in text {
      if let nextNode = current.children[char] {
        current = nextNode
        if current.isEndOfWord {
          longestMatch = current.value
        }
      } else {
        break
      }
    }
    
    return longestMatch
  }
}
