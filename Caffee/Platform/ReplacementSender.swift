//
//  ReplacementSender.swift
//  Caffee
//

import Foundation

protocol ReplacementSender {
  func sendReplacement(
    backspaceCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  )

  func sendSelectAndReplace(
    selectLeftCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  )
}

struct EventSimulatorReplacementSender: ReplacementSender {
  func sendReplacement(
    backspaceCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  ) {
    EventSimulator.sendReplacement(
      backspaceCount: backspaceCount,
      diffChars: diffChars,
      strategy: strategy
    )
  }

  func sendSelectAndReplace(
    selectLeftCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  ) {
    EventSimulator.sendSelectAndReplace(
      selectLeftCount: selectLeftCount,
      diffChars: diffChars,
      strategy: strategy
    )
  }
}
