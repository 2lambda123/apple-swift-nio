//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if swift(>=5.5) && canImport(_Concurrency)
public typealias NIOSendable = Swift.Sendable
#else
public typealias NIOSendable = Any
#endif

#if swift(>=5.6)
@preconcurrency public protocol NIOPreconcurrencySendable: Sendable {}
#else
public protocol NIOPreconcurrencySendable {}
#endif

#if swift(>=5.5) && canImport(_Concurrency)
@usableFromInline
internal struct UncheckedSendable<Value>: @unchecked Sendable {
    @usableFromInline
    var value: Value
    @inlinable
    init(_ value: Value) {
        self.value = value
    }
}
#endif
