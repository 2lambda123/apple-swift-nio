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
#if canImport(Darwin) || os(Linux)

#if canImport(Darwin)
import CNIODarwin
#elseif os(Linux)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import CNIOLinux
#endif

/// A vsock socket address.
///
/// A socket address is defined as a combination of a Context Identifier (CID) and a port number.
/// The CID identifies the source or destination, which is either a virtual machine or the host.
/// The port number differentiates between multiple services running on a single machine.
///
/// For well-known CID values and port numbers, see `VsockAddress.ContextID` and `VsockAddress.Port` respectively.
public struct VsockAddress: Hashable, Sendable {
    /// The context ID associated with the address.
    public var cid: ContextID

    /// The port associated with the address.
    public var port: Port

    /// Creates a new vsock address.
    ///
    /// - parameters:
    ///   - cid: the context ID.
    ///   - port: the target port.
    /// - returns: the address for the given context ID and port combination.
    public init(cid: ContextID, port: Port) {
        self.cid = cid
        self.port = port
    }

    /// A vsock Context Identifier (CID).
    ///
    /// The CID identifies the source or destination, which is either a virtual machine or the host.
    public struct ContextID: RawRepresentable, ExpressibleByIntegerLiteral, Hashable, Sendable {
        public var rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public init(integerLiteral value: UInt32) {
            self.init(rawValue: value)
        }

        /// Wildcard, matches any address.
        ///
        /// On all platforms, using this value with `bind(2)` means "any address".
        ///
        /// On Darwin platforms, the man page states this can be used with `connect(2)` to mean "this host".
        public static let any: Self = Self(rawValue: VMADDR_CID_ANY)

        /// The address of the hypervisor.
        public static let hypervisor: Self = Self(rawValue: UInt32(VMADDR_CID_HYPERVISOR))

        /// The address of the host.
        public static let host: Self = Self(rawValue: UInt32(VMADDR_CID_HOST))

#if os(Linux)
        /// The address for local communication (loopback).
        ///
        /// This directs packets to the same host that generated them.  This is useful for testing
        /// applications on a single host and for debugging.
        ///
        /// The local context ID obtained with ``getLocalContextID(_:)`` can be used for the same
        /// purpose, but it is preferable to use ``local``.
        ///
        /// This is equal to `VMADDR_CID_LCOAL`.
        ///
        /// - Seealso: https://man7.org/linux/man-pages/man7/vsock.7.html
        public static let local: Self = Self(rawValue: 1)
#endif

        /// Get the context ID of the local machine.
        ///
        /// This function wraps the `IOCTL_VM_SOCKETS_GET_LOCAL_CID` `ioctl()` request.
        ///
        /// To provide a consistent API on Linux and Darwin, this API takes a socket parameter, which is unused on Linux:
        ///
        /// - On Darwin, the `ioctl()` request operates on a socket.
        /// - On Linux, the `ioctl()` request operates on the `/dev/vsock` device.
        ///
        /// - NOTE: On Linux, ``local`` may be a better choice.
        public static func getLocalContextID(_ socketFD: NIOBSDSocket.Handle) throws -> Self {
#if canImport(Darwin)
            let request = CNIODarwin_IOCTL_VM_SOCKETS_GET_LOCAL_CID
            let fd = socketFD
#elseif os(Linux)
            let request = CNIOLinux_IOCTL_VM_SOCKETS_GET_LOCAL_CID
            let fd = open("/dev/vsock", O_RDONLY)
            precondition(fd >= 0, "couldn't open /dev/vsock (\(errno))")
            defer { close(fd) }
#endif
            var cid = ContextID.any.rawValue
            try SystemCalls.ioctl(fd: fd, request: request, ptr: &cid)
            precondition(cid != ContextID.any.rawValue)
            return Self(rawValue: cid)
        }
    }

    /// A vsock port number.
    ///
    /// The vsock port number differentiates between multiple services running on a single machine.
    public struct Port: RawRepresentable, ExpressibleByIntegerLiteral, Hashable, Sendable {
        public var rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public init(integerLiteral value: UInt32) {
            self.init(rawValue: value)
        }

        /// Used to bind to any port number.
        public static let any: Self = Self(rawValue: VMADDR_PORT_ANY)
    }
}

extension VsockAddress.ContextID: CustomStringConvertible {
    public var description: String {
        self == .any ? "-1" : self.rawValue.description
    }
}

extension VsockAddress.Port: CustomStringConvertible {
    public var description: String {
        self == .any ? "-1" : self.rawValue.description
    }
}

extension VsockAddress: CustomStringConvertible {
    public var description: String {
        "[VSOCK]\(self.cid):\(self.port)"
    }
}

extension VsockAddress: SockAddrProtocol {
    /// The libc socket address for a vsock socket.
    var address: sockaddr_vm {
        var addr = sockaddr_vm()
        addr.svm_family = sa_family_t(NIOBSDSocket.AddressFamily.vsock.rawValue)
        addr.svm_cid = self.cid.rawValue
        addr.svm_port = self.port.rawValue
        return addr
    }

    public func withSockAddr<T>(_ body: (UnsafePointer<sockaddr>, Int) throws -> T) rethrows -> T {
        try self.address.withSockAddr({ try body($0, $1) })
    }
}

extension NIOBSDSocket.AddressFamily {
    /// Address for vsock.
    public static let vsock: NIOBSDSocket.AddressFamily =
            NIOBSDSocket.AddressFamily(rawValue: AF_VSOCK)
}

extension NIOBSDSocket.ProtocolFamily {
    /// Vsock protocol.
    public static let vsock: NIOBSDSocket.ProtocolFamily =
            NIOBSDSocket.ProtocolFamily(rawValue: PF_VSOCK)
}

extension sockaddr_vm: SockAddrProtocol {
    func withSockAddr<R>(_ body: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R {
        return try withUnsafeBytes(of: self) { p in
            try body(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
        }
    }
}
#endif  // canImport(Darwin) || os(Linux)
