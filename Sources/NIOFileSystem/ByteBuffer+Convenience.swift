//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension ByteBuffer {
    /// Reads the contents of the file at the path.
    ///
    /// - Parameters:
    ///   - path: The path of the file to read.
    ///   - maximumSizeAllowed: The maximum size of file which can be read, in bytes, as a ``ByteCount``.
    ///   - fileSystem: The ``FileSystemProtocol`` instance to use to read the file.
    public init(
        contentsOf path: FilePath,
        maximumSizeAllowed: ByteCount,
        fileSystem: some FileSystemProtocol
    ) async throws {
        self = try await fileSystem.withFileHandle(forReadingAt: path) { handle in
            try await handle.readToEnd(
                fromAbsoluteOffset: 0,
                maximumSizeAllowed: maximumSizeAllowed
            )
        }
    }

    /// Reads the contents of the file at the path using ``FileSystem``.
    ///
    /// - Parameters:
    ///   - path: The path of the file to read.
    ///   - maximumSizeAllowed: The maximum size of file which can be read, as a ``ByteCount``.
    public init(
        contentsOf path: FilePath,
        maximumSizeAllowed: ByteCount
    ) async throws {
        self = try await Self(
            contentsOf: path,
            maximumSizeAllowed: maximumSizeAllowed,
            fileSystem: .shared
        )
    }
}
