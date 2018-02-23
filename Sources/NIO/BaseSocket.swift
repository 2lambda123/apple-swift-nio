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

/// A Registration on a `Selector`, which is interested in an `IOEvent`.
protocol Registration {
    /// The `IOEvent` in which the `Registration` is interested.
    var interested: IOEvent { get set }
}

protocol SockAddrProtocol {
    mutating func withSockAddr<R>(_ fn: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R
    mutating func withMutableSockAddr<R>(_ fn: (UnsafeMutablePointer<sockaddr>, Int) throws -> R) rethrows -> R
}

/// Returns a description for the given address.
private func descriptionForAddress(family: CInt, bytes: UnsafeRawPointer, length byteCount: Int) -> String {
    var addressBytes: [Int8] = Array(repeating: 0, count: byteCount)
    return addressBytes.withUnsafeMutableBufferPointer { (addressBytesPtr: inout UnsafeMutableBufferPointer<Int8>) -> String in
        try! Posix.inet_ntop(addressFamily: family,
                             addressBytes: bytes,
                             addressDescription: addressBytesPtr.baseAddress!,
                             addressDescriptionLength: socklen_t(byteCount))
        return addressBytesPtr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: byteCount) { addressBytesPtr -> String in
            return String(decoding: UnsafeBufferPointer<UInt8>(start: addressBytesPtr, count: byteCount), as: Unicode.ASCII.self)
        }
    }
}

extension sockaddr_in: SockAddrProtocol {
    mutating func withSockAddr<R>(_ fn: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }

    mutating func withMutableSockAddr<R>(_ fn: (UnsafeMutablePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeMutableBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }

    /// Returns a description of the `sockaddr_in`.
    mutating func addressDescription() -> String {
        return withUnsafePointer(to: &self.sin_addr) { addrPtr in
            descriptionForAddress(family: AF_INET, bytes: addrPtr, length: Int(INET_ADDRSTRLEN))
        }
    }
}

extension sockaddr_in6: SockAddrProtocol {
    mutating func withSockAddr<R>(_ fn: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }

    mutating func withMutableSockAddr<R>(_ fn: (UnsafeMutablePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeMutableBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }

    /// Returns a description of the `sockaddr_in6`.
    mutating func addressDescription() -> String {
        return withUnsafePointer(to: &self.sin6_addr) { addrPtr in
            descriptionForAddress(family: AF_INET6, bytes: addrPtr, length: Int(INET6_ADDRSTRLEN))
        }
    }
}

extension sockaddr_un: SockAddrProtocol {
    mutating func withSockAddr<R>(_ fn: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }

    mutating func withMutableSockAddr<R>(_ fn: (UnsafeMutablePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeMutableBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }
}

extension sockaddr_storage: SockAddrProtocol {
    mutating func withSockAddr<R>(_ fn: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        var me = self
        return try withUnsafeBytes(of: &me) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }

    mutating func withMutableSockAddr<R>(_ fn: (UnsafeMutablePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        return try withUnsafeMutableBytes(of: &self) { p in
            try fn(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }
}

// sockaddr_storage is basically just a boring data structure that we can
// convert to being something sensible. These functions copy the data as
// needed.
//
// Annoyingly, these functions are mutating. This is required to work around
// https://bugs.swift.org/browse/SR-2749 on Ubuntu 14.04: basically, we need to
// avoid getting the Swift compiler to copy the sockaddr_storage for any reason:
// only our rebinding copy here is allowed.
extension sockaddr_storage {
    /// Converts the `socketaddr_storage` to a `sockaddr_in`.
    ///
    /// This will crash if `ss_family` != AF_INET!
    mutating func convert() -> sockaddr_in {
        precondition(self.ss_family == AF_INET)
        return withUnsafePointer(to: &self) {
            $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                $0.pointee
            }
        }
    }

    /// Converts the `socketaddr_storage` to a `sockaddr_in6`.
    ///
    /// This will crash if `ss_family` != AF_INET6!
    mutating func convert() -> sockaddr_in6 {
        precondition(self.ss_family == AF_INET6)
        return withUnsafePointer(to: &self) {
            $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                $0.pointee
            }
        }
    }

    /// Converts the `socketaddr_storage` to a `sockaddr_un`.
    ///
    /// This will crash if `ss_family` != AF_UNIX!
    mutating func convert() -> sockaddr_un {
        precondition(self.ss_family == AF_UNIX)
        return withUnsafePointer(to: &self) {
            $0.withMemoryRebound(to: sockaddr_un.self, capacity: 1) {
                $0.pointee
            }
        }
    }

    /// Converts the `socketaddr_storage` to a `SocketAddress`.
    mutating func convert() -> SocketAddress {
        switch self.ss_family {
        case Posix.AF_INET:
            var sockAddr: sockaddr_in = self.convert()
            return SocketAddress(sockAddr, host: sockAddr.addressDescription())
        case Posix.AF_INET6:
            var sockAddr: sockaddr_in6 = self.convert()
            return SocketAddress(sockAddr, host: sockAddr.addressDescription())
        case Posix.AF_UNIX:
            return SocketAddress(self.convert() as sockaddr_un)
        default:
            fatalError("unknown sockaddr family \(self.ss_family)")
        }
    }
}

/// Base class for sockets.
///
/// This should not be created directly but one of its sub-classes should be used, like `ServerSocket` or `Socket`.
class BaseSocket: Selectable {
    
    public let descriptor: Int32
    public private(set) var open: Bool
    
    /// Returns the local bound `SocketAddress` of the socket.
    ///
    /// - returns: The local bound address.
    /// - throws: An `IOError` if the retrieval of the address failed.
    final func localAddress() throws -> SocketAddress {
        return try get_addr { try Posix.getsockname(socket: $0, address: $1, addressLength: $2) }
    }
    
    /// Returns the connected `SocketAddress` of the socket.
    ///
    /// - returns: The connected address.
    /// - throws: An `IOError` if the retrieval of the address failed.
    final func remoteAddress() throws -> SocketAddress {
        return try get_addr { try Posix.getpeername(socket: $0, address: $1, addressLength: $2) }
    }

    /// Internal helper function for retrieval of a `SocketAddress`.
    private func get_addr(_ fn: (Int32, UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Void) throws -> SocketAddress {
        var addr = sockaddr_storage()

        try addr.withMutableSockAddr { addressPtr, size in
            var size = socklen_t(size)
            try fn(self.descriptor, addressPtr, &size)
        }
        return addr.convert()
    }

    /// Create a new socket and return the file descriptor of it.
    ///
    /// - parameters:
    ///     - protocolFamily: The protocol family to use (usually `AF_INET6` or `AF_INET`).
    ///     - type: The type of the socket to create.
    /// - returns: the file descriptor of the socket that was created.
    /// - throws: An `IOError` if creation of the socket failed.
    static func newSocket(protocolFamily: Int32, type: CInt) throws -> Int32 {
        let sock = try Posix.socket(domain: protocolFamily,
                                    type: type,
                                    protocol: 0)
        
        if protocolFamily == AF_INET6 {
            var zero: Int32 = 0
            do {
                _ = try Posix.setsockopt(socket: sock, level: Int32(IPPROTO_IPV6), optionName: IPV6_V6ONLY, optionValue: &zero, optionLen: socklen_t(MemoryLayout.size(ofValue: zero)))

            } catch let e as IOError {
                if e.errnoCode != EAFNOSUPPORT {
                    // Ignore error that may be thrown by close.
                    _ = try? Posix.close(descriptor: sock)
                    throw e
                }
                /* we couldn't enable dual IP4/6 support, that's okay too. */
            } catch let e {
                fatalError("Unexpected error type \(e)")
            }
        }
        return sock
    }

    /// Create a new instance.
    ///
    /// The ownership of the passed in descriptor is transferred to this class. A user must call `close` to close the underlying
    /// file descriptor once its not needed / used anymore.
    ///
    /// - parameters:
    ///     - descriptor: The file descriptor to wrap.
    init(descriptor : Int32) {
        self.descriptor = descriptor
        self.open = true
    }

    deinit {
        assert(!self.open, "leak of open BaseSocket")
    }
    
    /// Set the socket as non-blocking.
    ///
    /// All I/O operations will not block and so may return before the actual action could be completed.
    ///
    /// throws: An `IOError` if the operation failed.
    final func setNonBlocking() throws {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't control file descriptor as it's not open anymore.")
        }

        try Posix.fcntl(descriptor: descriptor, command: F_SETFL, value: O_NONBLOCK)
    }
    
    /// Set the given socket option.
    ///
    /// This basically just delegates to `setsockopt` syscall.
    ///
    /// - parameters:
    ///     - level: The protocol level (see `man setsockopt`).
    ///     - name: The name of the option to set.
    ///     - value: The value for the option.
    /// - throws: An `IOError` if the operation failed.
    final func setOption<T>(level: Int32, name: Int32, value: T) throws {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't set socket options as it's not open anymore.")
        }

        var val = value
        
        _ = try Posix.setsockopt(
            socket: self.descriptor,
            level: level,
            optionName: name,
            optionValue: &val,
            optionLen: socklen_t(MemoryLayout.size(ofValue: val)))
    }

    /// Get the given socket option value.
    ///
    /// This basically just delegates to `getsockopt` syscall.
    ///
    /// - parameters:
    ///     - level: The protocol level (see `man getsockopt`).
    ///     - name: The name of the option to set.
    /// - throws: An `IOError` if the operation failed.
    final func getOption<T>(level: Int32, name: Int32) throws -> T {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't get socket options as it's not open anymore.")
        }

        var length = socklen_t(MemoryLayout<T>.size)
        var val = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer {
            val.deinitialize(count: 1)
            val.deallocate()
        }
        
        try Posix.getsockopt(socket: self.descriptor, level: level, optionName: name, optionValue: val, optionLen: &length)
        return val.pointee
    }
    
    /// Bind the socket to the given `SocketAddress`.
    ///
    /// - parameters:
    ///     - address: The `SocketAddress` to which the socket should be bound.
    /// - throws: An `IOError` if the operation failed.
    final func bind(to address: SocketAddress) throws {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't bind socket as it's not open anymore.")
        }

        func doBind(ptr: UnsafePointer<sockaddr>, bytes: Int) throws {
           try Posix.bind(descriptor: self.descriptor, ptr: ptr, bytes: bytes)
        }

        switch address {
        case .v4(let address):
            var addr = address.address
            try addr.withSockAddr(doBind)
        case .v6(let address):
            var addr = address.address
            try addr.withSockAddr(doBind)
        case .unixDomainSocket(let address):
            var addr = address.address
            try addr.withSockAddr(doBind)
        }
    }
    
    /// Close the socket.
    ///
    /// After the socket was closed all other methods will throw an `IOError` when called.
    ///
    /// - throws: An `IOError` if the operation failed.
    final func close() throws {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't close socket (as it's not open anymore.")
        }

        try Posix.close(descriptor: self.descriptor)

        self.open = false
    }
}
