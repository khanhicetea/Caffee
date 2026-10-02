//
//  FileMonitor.swift
//  Caffee
//
//  Created by KhanhIceTea on 10/3/24.
//

import Foundation

protocol FileMonitorDelegate: AnyObject {
  func didReceive(changes: String)
}

/// Watches a small control file and reports its (trimmed) full contents whenever it changes.
///
/// Handles `echo vi > file` (truncate + write), appends, and the file being deleted or atomically
/// replaced by its writer. Empty contents are ignored: a truncating write briefly leaves the file
/// empty before the new text lands, and must not be mistaken for a command.
// All state is only touched on the main queue (the dispatch source targets it).
final class FileMonitor: @unchecked Sendable {

  let url: URL
  weak var delegate: FileMonitorDelegate?

  private var source: DispatchSourceFileSystemObject?

  init(url: URL) throws {
    self.url = url
    try start()
  }

  deinit {
    source?.cancel()
  }

  private func start() throws {
    let fd = open(url.path, O_EVTONLY)
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: [.write, .extend, .delete, .rename],
      queue: DispatchQueue.main
    )
    source.setEventHandler { [weak self] in
      guard let self, let event = self.source?.data else { return }
      self.process(event: event)
    }
    source.setCancelHandler { close(fd) }
    self.source = source
    source.resume()
  }

  func process(event: DispatchSource.FileSystemEvent) {
    if event.contains(.delete) || event.contains(.rename) {
      restartAfterReplacement()
    }
    deliverContents()
  }

  /// The watched inode is gone (deleted, or replaced by an atomic write). Re-attach to the path.
  private func restartAfterReplacement() {
    source?.cancel()
    source = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self else { return }
      if !FileManager.default.fileExists(atPath: self.url.path) {
        FileManager.default.createFile(atPath: self.url.path, contents: nil)
      }
      try? self.start()
      self.deliverContents()
    }
  }

  private func deliverContents() {
    // Skip partial UTF-8 (writer still appending) and the transient empty state.
    guard let string = try? String(contentsOf: url, encoding: .utf8) else { return }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    delegate?.didReceive(changes: trimmed)
  }
}
