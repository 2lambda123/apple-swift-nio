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

import NIO
import NIOWebSocket

final class WebSocketFrameDecoderBenchmark {
    private let channel: EmbeddedChannel
    private let runCount: Int
    private let dataSize: Int
    private let maskingKey: WebSocketMaskingKey?
    private var data: ByteBuffer!

    init(dataSize: Int, runCount: Int, maskingKey: WebSocketMaskingKey? = nil) {
        channel = EmbeddedChannel()
        self.dataSize = dataSize
        self.maskingKey = maskingKey
        self.runCount = runCount
    }
}

extension WebSocketFrameDecoderBenchmark: Benchmark {
    func setUp() throws {
        data = ByteBufferAllocator().webSocketFrame(size: dataSize, maskingKey: maskingKey)
        try channel.pipeline.addHandler(ByteToMessageHandler(WebSocketFrameDecoder(maxFrameSize: dataSize))).wait()
    }

    func tearDown() {
        _ = try! channel.finish()
    }

    func run() throws -> Int {
        for _ in 0 ..< runCount {
            try channel.writeInbound(data)
            let _: WebSocketFrame? = try channel.readInbound()
        }
        return 1
    }
}

private extension ByteBufferAllocator {
    func webSocketFrame(size: Int, maskingKey: WebSocketMaskingKey?) -> ByteBuffer {
        var data = buffer(capacity: size)

        // Calculate some information about the mask.
        let maskBitMask: UInt8 = maskingKey != nil ? 0x80 : 0x00

        // Time to add the extra bytes. To avoid checking this twice, we also start writing stuff out here.
        switch size {
        case 0 ... 125:
            data.writeInteger(UInt8(0x81))
            data.writeInteger(UInt8(size) | maskBitMask)
        case 126 ... Int(UInt16.max):
            data.writeInteger(UInt8(0x81))
            data.writeInteger(UInt8(126) | maskBitMask)
            data.writeInteger(UInt16(size))
        default:
            data.writeInteger(UInt8(0x81))
            data.writeInteger(UInt8(127) | maskBitMask)
            data.writeInteger(UInt64(size))
        }

        if let maskingKey = maskingKey {
            data.writeBytes(maskingKey)
        }

        data.writeBytes(repeatElement(0, count: size))
        return data
    }
}
