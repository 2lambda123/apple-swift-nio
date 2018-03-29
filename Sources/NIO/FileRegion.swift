//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A `FileRegion` represent a readable portion usually created to be sent over the network.
///
/// Usually a `FileRegion` will allow the underlying transport to use `sendfile` to transfer its content and so allows transferring
/// the file content without copying it into user-space at all. If the actual transport implementation really can make use of sendfile
/// or if it will need to copy the content to user-space first and use `write` / `writev` is an implementation detail. That said
///  using `FileRegion` is the recommended way to transfer file content if possible.
///
/// One important note, depending your `ChannelPipeline` setup it may not be possible to use a `FileRegion` as a `ChannelHandler` may
/// need access to the bytes (in a `ByteBuffer`) to transform these.
///
/// - note: It is important to manually manage the lifetime of the `FileHandle` used to create a `FileRegion`.
public struct FileRegion {

    /// The `FileHandle` that is used by this `FileRegion`.
    public let fileHandle: FileHandle

    /// The current reader index of this `FileRegion`
    private(set) public var readerIndex: Int

    /// The end index of this `FileRegion`.
    public let endIndex: Int

    /// Create a new `FileRegion` from an open `FileHandle`.
    ///
    /// - parameters:
    ///     - fileHandle: the `FileHandle` to use.
    ///     - readerIndex: the index (offset) on which the reading will start.
    ///     - endIndex: the index which represent the end of the readable portion.
    public init(fileHandle: FileHandle, readerIndex: Int, endIndex: Int) {
        precondition(readerIndex <= endIndex, "readerIndex(\(readerIndex) must be <= endIndex(\(endIndex).")

        self.fileHandle = fileHandle
        self.readerIndex = readerIndex
        self.endIndex = endIndex
    }

    /// The number of readable bytes within this FileRegion (taking the `readerIndex` and `endIndex` into account).
    public var readableBytes: Int {
        return endIndex - readerIndex
    }

    /// Move the readerIndex forward by `offset`.
    public mutating func moveReaderIndex(forwardBy offset: Int) {
        let newIndex = self.readerIndex + offset
        assert(offset >= 0 && newIndex <= endIndex, "new readerIndex: \(newIndex), expected: range(0, \(endIndex))")
        self.readerIndex = newIndex
    }
}

extension FileRegion {
    /// Create a new `FileRegion` forming a complete file.
    ///
    /// - parameters:
    ///     - fileHandle: An open `FileHandle` to the file.
    public init(fileHandle: FileHandle) throws {
        let eof = try fileHandle.withUnsafeFileDescriptor { (fd: CInt) throws -> off_t in
            let eof = try Posix.lseek(descriptor: fd, offset: 0, whence: SEEK_END)
            try Posix.lseek(descriptor: fd, offset: 0, whence: SEEK_SET)
            return eof
        }
        self.init(fileHandle: fileHandle, readerIndex: 0, endIndex: Int(eof))
    }

}

extension FileRegion: Equatable {
    public static func ==(lhs: FileRegion, rhs: FileRegion) -> Bool {
        return lhs.fileHandle === rhs.fileHandle && lhs.readerIndex == rhs.readerIndex && lhs.endIndex == rhs.endIndex
    }
}

extension FileRegion: CustomStringConvertible {
    public var description: String {
        return "FileRegion(handle: \(self.fileHandle), readerIndex: \(self.readerIndex), endIndex: \(self.endIndex))"
    }
}
