//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIO

final class CircularBufferIntoByteBufferBenchmark: Benchmark {
    private let iterations: Int
    private let bufferSize: Int
    private var circularBuffer: CircularBuffer<UInt8>
    private var buffer: ByteBuffer

    init(iterations: Int, bufferSize: Int) {
        self.iterations = iterations
        self.bufferSize = bufferSize
        circularBuffer = CircularBuffer<UInt8>(initialCapacity: self.bufferSize)
        buffer = ByteBufferAllocator().buffer(capacity: self.bufferSize)
    }

    func setUp() throws {
        for i in 0 ..< bufferSize {
            circularBuffer.append(UInt8(i % 256))
        }
    }

    func tearDown() {}

    func run() -> Int {
        for _ in 1 ... iterations {
            buffer.writeBytes(circularBuffer)
            buffer.setBytes(circularBuffer, at: 0)
            buffer.clear()
        }
        return 1
    }
}
