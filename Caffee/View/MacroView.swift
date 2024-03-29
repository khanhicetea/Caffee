//
//  MacroView.swift
//  Caffee
//
//  Created by KhanhIceTea on 12/3/24.
//

import Foundation
import SwiftUI

// TODO : Macro
//struct Macro: Identifiable {
//  var from: String
//  var to: String
//  let id = UUID()
//}
//
//struct MacroView: View {
//
//  @ObservedObject var appState: AppState
//  @State private var selectedMacros = Set<Macro.ID>()
//
//  var body: some View {
//    ScrollViewReader { proxy in
//      VStack {
//        Table(appState.macros, selection: $selectedMacros) {
//          TableColumn("Viết tắt") { mc in
//            TextField(
//              "To",
//              text: Binding(
//                get: {
//                  return mc.from
//                },
//                set: { newValue in
//                  if let index = appState.macros.firstIndex(where: { $0.id == mc.id }) {
//                    appState.macros[index].from = newValue
//                  }
//                }))
//          }
//          TableColumn("Từ mới") { mc in
//            TextField(
//              "To",
//              text: Binding(
//                get: {
//                  return mc.to
//                },
//                set: { newValue in
//                  if let index = appState.macros.firstIndex(where: { $0.id == mc.id }) {
//                    appState.macros[index].to = newValue
//                  }
//                })
//            )
//            .border(Color.purple)
//            .frame(maxWidth: .infinity)
//            .onTapGesture {
//              print("Tapped")
//            }
//          }
//        }
//        HStack {
//          Button(
//            "Add", systemImage: "plus",
//            action: {
//              let newMacro = Macro(from: "...", to: "...")
//              appState.macros.insert(newMacro, at: 0)
//              selectedMacros.removeAll()
//              selectedMacros.update(with: newMacro.id)
//            })
//          Button(
//            "Delete", systemImage: "trash",
//            action: {
//              appState.macros.removeAll { macro in
//                return selectedMacros.contains(macro.id)
//              }
//              selectedMacros = Set<Macro.ID>()
//            })
//          Text("\(selectedMacros.count) macro selected")
//        }
//      }
//      .frame(width: 400, height: 200)
//      .padding(10)
//    }
//  }
//}
