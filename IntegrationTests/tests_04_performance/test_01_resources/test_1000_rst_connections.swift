//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOPosix

func run(identifier: String) {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
        try! group.syncShutdownGracefully()
    }

    let serverConnection = try! ServerBootstrap(group: group)
        .bind(host: "localhost", port: 0)
        .wait()
    
    let serverAddress = serverConnection.localAddress!
    let clientBootstrap = ClientBootstrap(group: group)

    measure(identifier: identifier, trackFDs: true) {
        let iterations = 1000
        for _ in 0..<iterations {
            let conn = clientBootstrap.connect(to: serverAddress)
            
            let _: Void? = try? conn.flatMap { channel in
                (channel as! SocketOptionProvider).setSoLinger(linger(l_onoff: 1, l_linger: 0)).flatMap {
                    channel.close()
                }
            }.wait()
        }
        return iterations
    }
}
