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

let sysMalloc: @convention(c) (size_t) -> UnsafeMutableRawPointer? = malloc
let sysRealloc: @convention(c) (UnsafeMutableRawPointer?, size_t) -> UnsafeMutableRawPointer? = realloc
let sysFree: @convention(c) (UnsafeMutableRawPointer?) -> Void = free

extension _ByteBufferSlice: Equatable {}

/// The slice of a `ByteBuffer`, it's different from `Range<UInt32>` because the lower bound is actually only
/// 24 bits (the upper bound is still 32). Before constructing, you need to make sure the lower bound actually
/// fits within 24 bits, otherwise the behaviour is undefined.
@usableFromInline
struct _ByteBufferSlice {
    @usableFromInline
    var upperBound: ByteBuffer._Index
    
    @usableFromInline
    var _begin: _UInt24
    
    @usableFromInline
    var lowerBound: ByteBuffer._Index {
        return UInt32(self._begin)
    }
    
    @inlinable
    var count: Int {
        return Int(self.upperBound - self.lowerBound)
    }
    
    @inlinable
    init() {
        self._begin = 0
        self.upperBound = 0
    }
    
    static var maxSupportedLowerBound: ByteBuffer._Index {
        return ByteBuffer._Index(_UInt24.max)
    }
}

extension _ByteBufferSlice {
    @inlinable
    init(_ range: Range<UInt32>) {
        self = _ByteBufferSlice()

        self._begin = _UInt24(range.lowerBound)
        self.upperBound = range.upperBound
    }
}

/// The preferred allocator for `ByteBuffer` values. The allocation strategy is opaque but is currently libc's
/// `malloc`, `realloc` and `free`.
///
/// - note: `ByteBufferAllocator` is thread-safe.
public struct ByteBufferAllocator {
    /// Create a fresh `ByteBufferAllocator`. In the future the allocator might use for example allocation pools and
    /// therefore it's recommended to reuse `ByteBufferAllocators` where possible instead of creating fresh ones in
    /// many places.
    public init() {
    }

    /// Request a freshly allocated `ByteBuffer` of size `capacity` or larger.
    ///
    /// - parameters:
    ///     - capacity: The capacity of the returned `ByteBuffer`.
    public func buffer(capacity: Int) -> ByteBuffer {
        return ByteBuffer(capacity: capacity)
    }
}

/// `ByteBuffer` stores contiguously allocated raw bytes. It is a random and sequential accessible sequence of zero or
/// more bytes (octets).
///
/// ### Allocation
/// Use `allocator.buffer(capacity: desiredCapacity)` to allocate a new `ByteBuffer`.
///
/// ### Supported types
/// A variety of types can be read/written from/to a `ByteBuffer`. Using Swift's `extension` mechanism you can easily
/// create `ByteBuffer` support for your own data types. Out of the box, `ByteBuffer` supports for example the following
/// types (non-exhaustive list):
///
///  - `String`/`StaticString`
///  - Swift's various (unsigned) integer types
///  - `Foundation`'s `Data`
///  - `[UInt8]` and generally any `Collection` (& `ContiguousCollection`) of `UInt8`
///
/// ### Random Access
/// For every supported type `ByteBuffer` usually contains two methods for random access:
///
///  1. `get<type>(at: Int, length: Int)` where `<type>` is for example `String`, `Data`, `Bytes` (for `[UInt8]`)
///  2. `set(<type>: Type, at: Int)`
///
/// Example:
///
///     var buf = ...
///     buf.set(string: "Hello World", at: 0)
///     let helloWorld = buf.getString(at: 0, length: 11)
///
///     buf.set(integer: 17 as Int, at: 11)
///     let seventeen: Int = buf.getInteger(at: 11)
///
/// If needed, `ByteBuffer` will automatically resize its storage to accommodate your `set` request.
///
/// ### Sequential Access
/// `ByteBuffer` provides two properties which are indices into the `ByteBuffer` to support sequential access:
///  - `readerIndex`, the index of the next readable byte
///  - `writerIndex`, the index of the next byte to write
///
/// For every supported type `ByteBuffer` usually contains two methods for sequential access:
///
///  1. `read<type>(length: Int)` to read `length` bytes from the current `readerIndex` (and then advance the reader index by `length` bytes)
///  2. `write(<type>: Type)` to write, advancing the `writerIndex` by the appropriate amount
///
/// Example:
///
///      var buf = ...
///      buf.write(string: "Hello World")
///      buf.write(integer: 17 as Int)
///      let helloWorld = buf.readString(length: 11)
///      let seventeen: Int = buf.readInteger()
///
/// ### Layout
///     +-------------------+------------------+------------------+
///     | discardable bytes |  readable bytes  |  writable bytes  |
///     |                   |     (CONTENT)    |                  |
///     +-------------------+------------------+------------------+
///     |                   |                  |                  |
///     0      <=      readerIndex   <=   writerIndex    <=    capacity
///
/// The 'discardable bytes' are usually bytes that have already been read, they can however still be accessed using
/// the random access methods. 'Readable bytes' are the bytes currently available to be read using the sequential
/// access interface (`read<Type>`/`write<Type>`). Getting `writableBytes` (bytes beyond the writer index) is undefined
/// behaviour and might yield arbitrary bytes (_not_ `0` initialised).
///
/// ### Slicing
/// `ByteBuffer` supports slicing a `ByteBuffer` without copying the underlying storage.
///
/// Example:
///
///     var buf = ...
///     let dataBytes: [UInt8] = [0xca, 0xfe, 0xba, 0xbe]
///     let dataBytesLength = UInt32(dataBytes.count)
///     buf.write(integer: dataBytesLength) /* the header */
///     buf.write(bytes: dataBytes) /* the data */
///     let bufDataBytesOnly = buf.getSlice(at: 4, length: dataBytes.count)
///     /* `bufDataByteOnly` and `buf` will share their storage */
///
/// ### Important usage notes
/// Each method that is prefixed with `get` is considered "unsafe" as it allows the user to read uninitialized memory if the `index` or `index + length` points outside of the previous written
/// range of the `ByteBuffer`. Because of this it's strongly advised to prefer the usage of methods that start with the `read` prefix and only use the `get` prefixed methods if there is a strong reason
/// for doing so. In any case, if you use the `get` prefixed methods you are responsible for ensuring that you do not reach into uninitialized memory by taking the `readableBytes` and `readerIndex` into
/// account, and ensuring that you have previously written into the area covered by the `index` itself.

/*
public struct ByteBuffer {
    @usableFromInline typealias Slice = _ByteBufferSlice
    @usableFromInline typealias Allocator = ByteBufferAllocator
    // these two type aliases should be made `@usableFromInline internal` for
    // the 2.0 release when we can drop Swift 4.0 & 4.1 support. The reason they
    // must be public is because Swift 4.0 and 4.1 don't support attributes for
    // typealiases and Swift 4.2 warns if those attributes aren't present and
    // the type is internal.
    public typealias _Index = UInt32
    public typealias _Capacity = UInt32

    @usableFromInline var _storage: _Storage
    @usableFromInline var _readerIndex: _Index = 0
    @usableFromInline var _writerIndex: _Index = 0
    @usableFromInline var _slice: Slice

    // MARK: Internal _Storage for CoW
    @usableFromInline final class _Storage {
        private(set) var capacity: _Capacity
        @usableFromInline private(set) var bytes: UnsafeMutableRawPointer
        private let allocator: ByteBufferAllocator

        public init(bytesNoCopy: UnsafeMutableRawPointer, capacity: _Capacity, allocator: ByteBufferAllocator) {
            self.bytes = bytesNoCopy
            self.capacity = capacity
            self.allocator = allocator
        }

        deinit {
            self.deallocate()
        }

        internal var fullSlice: _ByteBufferSlice {
            return _ByteBufferSlice(0..<self.capacity)
        }

        private static func allocateAndPrepareRawMemory(bytes: _Capacity, allocator: Allocator) -> UnsafeMutableRawPointer {
            let ptr = allocator.malloc(size_t(bytes))!
            /* bind the memory so we can assume it elsewhere to be bound to UInt8 */
            ptr.bindMemory(to: UInt8.self, capacity: Int(bytes))
            return ptr
        }

        public func allocateStorage() -> _Storage {
            return self.allocateStorage(capacity: self.capacity)
        }

        private func allocateStorage(capacity: _Capacity) -> _Storage {
            let newCapacity = capacity == 0 ? 0 : capacity.nextPowerOf2ClampedToMax()
            return _Storage(bytesNoCopy: _Storage.allocateAndPrepareRawMemory(bytes: newCapacity, allocator: self.allocator),
                            capacity: newCapacity,
                            allocator: self.allocator)
        }

        public func reallocSlice(_ slice: Range<ByteBuffer._Index>, capacity: _Capacity) -> _Storage {
            assert(slice.count <= capacity)
            let new = self.allocateStorage(capacity: capacity)
            self.allocator.memcpy(new.bytes, self.bytes.advanced(by: Int(slice.lowerBound)), size_t(slice.count))
            return new
        }

        public func reallocStorage(capacity minimumNeededCapacity: _Capacity) {
            let newCapacity = minimumNeededCapacity.nextPowerOf2ClampedToMax()
            let ptr = self.allocator.realloc(self.bytes, size_t(newCapacity))!
            /* bind the memory so we can assume it elsewhere to be bound to UInt8 */
            ptr.bindMemory(to: UInt8.self, capacity: Int(newCapacity))
            self.bytes = ptr
            self.capacity = newCapacity
        }

        private func deallocate() {
            self.allocator.free(self.bytes)
        }

        public static func reallocated(minimumCapacity: _Capacity, allocator: Allocator) -> _Storage {
            let newCapacity = minimumCapacity == 0 ? 0 : minimumCapacity.nextPowerOf2ClampedToMax()
            // TODO: Use realloc if possible
            return _Storage(bytesNoCopy: _Storage.allocateAndPrepareRawMemory(bytes: newCapacity, allocator: allocator),
                            capacity: newCapacity,
                            allocator: allocator)
        }

        public func dumpBytes(slice: Slice, offset: Int, length: Int) -> String {
            var desc = "["
            let bytes = UnsafeRawBufferPointer(start: self.bytes, count: Int(self.capacity))
            for byte in bytes[Int(slice.lowerBound) + offset ..< Int(slice.lowerBound) + offset + length] {
                let hexByte = String(byte, radix: 16)
                desc += " \(hexByte.count == 1 ? "0" : "")\(hexByte)"
            }
            desc += " ]"
            return desc
        }
    }

    private mutating func _copyStorageAndRebase(capacity: _Capacity, resetIndices: Bool = false) {
        let indexRebaseAmount = resetIndices ? self._readerIndex : 0
        let storageRebaseAmount = self._slice.lowerBound + indexRebaseAmount
        let newSlice = storageRebaseAmount ..< min(storageRebaseAmount + _toCapacity(self._slice.count), self._slice.upperBound, storageRebaseAmount + capacity)
        self._storage = self._storage.reallocSlice(newSlice, capacity: capacity)
        self._moveReaderIndex(to: self._readerIndex - indexRebaseAmount)
        self._moveWriterIndex(to: self._writerIndex - indexRebaseAmount)
        self._slice = self._storage.fullSlice
    }

    @usableFromInline mutating func _copyStorageAndRebase(extraCapacity: _Capacity = 0, resetIndices: Bool = false) {
        self._copyStorageAndRebase(capacity: _toCapacity(self._slice.count) + extraCapacity, resetIndices: resetIndices)
    }

    @usableFromInline mutating func _ensureAvailableCapacity(_ capacity: _Capacity, at index: _Index) {
        assert(isKnownUniquelyReferenced(&self._storage))

        let totalNeededCapacityWhenKeepingSlice = self._slice.lowerBound + index + capacity
        if totalNeededCapacityWhenKeepingSlice > self._slice.upperBound {
            // we need to at least adjust the slice's upper bound which we can do as we're the unique owner of the storage,
            // let's see if adjusting the slice's upper bound buys us enough storage
            if totalNeededCapacityWhenKeepingSlice > self._storage.capacity {
                let newStorageMinCapacity = index + capacity
                // nope, we need to actually re-allocate again. If our slice does not start at 0, let's also rebase
                if self._slice.lowerBound == 0 {
                    self._storage.reallocStorage(capacity: newStorageMinCapacity)
                } else {
                    self._storage = self._storage.reallocSlice(self._slice.lowerBound ..< self._slice.upperBound,
                                                               capacity: newStorageMinCapacity)
                }
                self._slice = self._storage.fullSlice
            } else {
                // yes, let's just extend the slice until the end of the buffer
                self._slice = _ByteBufferSlice(_slice.lowerBound ..< self._storage.capacity)
            }
        }
        assert(self._slice.lowerBound + index + capacity <= self._slice.upperBound)
        assert(self._slice.lowerBound >= 0, "illegal slice: negative lower bound: \(self._slice.lowerBound)")
        assert(self._slice.upperBound <= self._storage.capacity, "illegal slice: upper bound (\(self._slice.upperBound)) exceeds capacity: \(self._storage.capacity)")
    }

    // MARK: Internal API

    @inlinable
    mutating func _moveReaderIndex(to newIndex: _Index) {
        assert(newIndex >= 0 && newIndex <= writerIndex)
        self._readerIndex = newIndex
    }

    @inlinable
    mutating func _moveReaderIndex(forwardBy offset: Int) {
        let newIndex = self._readerIndex + _toIndex(offset)
        self._moveReaderIndex(to: newIndex)
    }

    @inlinable
    mutating func _moveWriterIndex(to newIndex: _Index) {
        assert(newIndex >= 0 && newIndex <= _toCapacity(self._slice.count))
        self._writerIndex = newIndex
    }

    @inlinable
    mutating func _moveWriterIndex(forwardBy offset: Int) {
        let newIndex = self._writerIndex + _toIndex(offset)
        self._moveWriterIndex(to: newIndex)
    }

    @inlinable
    mutating func _set(bytes: UnsafeRawBufferPointer, at index: _Index) -> _Capacity {
        let bytesCount = bytes.count
        let newEndIndex: _Index = index + _toIndex(bytesCount)
        if !isKnownUniquelyReferenced(&self._storage) {
            let extraCapacity = newEndIndex > self._slice.upperBound ? newEndIndex - self._slice.upperBound : 0
            self._copyStorageAndRebase(extraCapacity: extraCapacity)
        }

        self._ensureAvailableCapacity(_Capacity(bytesCount), at: index)
        let targetPtr = UnsafeMutableRawBufferPointer(rebasing: self._slicedStorageBuffer.dropFirst(Int(index)))
        targetPtr.copyMemory(from: bytes)
        return _toCapacity(Int(bytesCount))
    }

    @inline(never)
    @usableFromInline
    mutating func _setSlowPath<Bytes: Sequence>(bytes: Bytes, at index: _Index) -> _Capacity where Bytes.Element == UInt8 {
        func ensureCapacityAndReturnStorageBase(capacity: Int) -> UnsafeMutablePointer<UInt8> {
            self._ensureAvailableCapacity(_Capacity(capacity), at: index)
            let newBytesPtr = UnsafeMutableRawBufferPointer(rebasing: self._slicedStorageBuffer[Int(index) ..< Int(index) + Int(capacity)])
            return newBytesPtr.bindMemory(to: UInt8.self).baseAddress!
        }
        let underestimatedByteCount = bytes.underestimatedCount
        let newPastEndIndex: _Index = index + _toIndex(underestimatedByteCount)
        if !isKnownUniquelyReferenced(&self._storage) {
            let extraCapacity = newPastEndIndex > self._slice.upperBound ? newPastEndIndex - self._slice.upperBound : 0
            self._copyStorageAndRebase(extraCapacity: extraCapacity)
        }

        var base = ensureCapacityAndReturnStorageBase(capacity: underestimatedByteCount)
        var (iterator, idx) = UnsafeMutableBufferPointer(start: base, count: underestimatedByteCount).initialize(from: bytes)
        assert(idx == underestimatedByteCount)
        while let b = iterator.next() {
            base = ensureCapacityAndReturnStorageBase(capacity: idx + 1)
            base[idx] = b
            idx += 1
        }
        return _toCapacity(idx)
    }

    @inlinable
    mutating func _set<Bytes: Sequence>(bytes: Bytes, at index: _Index) -> _Capacity where Bytes.Element == UInt8 {
        if let written = bytes.withContiguousStorageIfAvailable({ bytes in
            self._set(bytes: UnsafeRawBufferPointer(bytes), at: index)
        }) {
            // fast path, we've got access to the contiguous bytes
            return written
        } else {
            return self._setSlowPath(bytes: bytes, at: index)
        }
    }

    // MARK: Public Core API

    fileprivate init(allocator: ByteBufferAllocator, startingCapacity: Int) {
        let startingCapacity = _toCapacity(startingCapacity)
        self._storage = _Storage.reallocated(minimumCapacity: startingCapacity, allocator: allocator)
        self._slice = self._storage.fullSlice
    }

    /// The number of bytes writable until `ByteBuffer` will need to grow its underlying storage which will likely
    /// trigger a copy of the bytes.
    public var writableBytes: Int { return Int(_toCapacity(self._slice.count) - self._writerIndex) }

    /// The number of bytes readable (`readableBytes` = `writerIndex` - `readerIndex`).
    public var readableBytes: Int { return Int(self._writerIndex - self._readerIndex) }

    /// The current capacity of the storage of this `ByteBuffer`, this is not constant and does _not_ signify the number
    /// of bytes that have been written to this `ByteBuffer`.
    public var capacity: Int {
        return self._slice.count
    }

    /// Reserves enough space to store the specified number of bytes.
    ///
    /// This method will ensure that the buffer has space for at least as many bytes as requested.
    /// This includes any bytes already stored, and completely disregards the reader/writer indices.
    /// If the buffer already has space to store the requested number of bytes, this method will be
    /// a no-op.
    ///
    /// - parameters:
    ///     - minimumCapacity: The minimum number of bytes this buffer must be able to store.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        guard minimumCapacity > self.capacity else {
            return
        }
        let targetCapacity = _toCapacity(minimumCapacity)

        if isKnownUniquelyReferenced(&self._storage) {
            // We have the unique reference. If we have the full slice, we can realloc. Otherwise
            // we have to copy memory anyway.
            self._ensureAvailableCapacity(targetCapacity, at: 0)
        } else {
            // We don't have a unique reference here, so we need to allocate and copy, no
            // optimisations available.
            self._copyStorageAndRebase(capacity: targetCapacity)
        }
    }

    @usableFromInline
    mutating func _copyStorageAndRebaseIfNeeded() {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._copyStorageAndRebase()
        }
    }

    @inlinable
    var _slicedStorageBuffer: UnsafeMutableRawBufferPointer {
        return UnsafeMutableRawBufferPointer(start: self._storage.bytes.advanced(by: Int(self._slice.lowerBound)),
                                             count: self._slice.count)
    }

    /// Yields a mutable buffer pointer containing this `ByteBuffer`'s readable bytes. You may modify those bytes.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes.
    /// - returns: The value returned by `fn`.
    @inlinable
    public mutating func withUnsafeMutableReadableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T {
        self._copyStorageAndRebaseIfNeeded()
        let readerIndex = self.readerIndex
        return try body(.init(rebasing: self._slicedStorageBuffer[readerIndex ..< readerIndex + self.readableBytes]))
    }

    /// Yields the bytes currently writable (`bytesWritable` = `capacity` - `writerIndex`). Before reading those bytes you must first
    /// write to them otherwise you will trigger undefined behaviour. The writer index will remain unchanged.
    ///
    /// - note: In almost all cases you should use `writeWithUnsafeMutableBytes` which will move the write pointer instead of this method
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and return the number of bytes written.
    /// - returns: The number of bytes written.
    @inlinable
    public mutating func withUnsafeMutableWritableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T {
        self._copyStorageAndRebaseIfNeeded()
        return try body(.init(rebasing: self._slicedStorageBuffer.dropFirst(self.writerIndex)))
    }

    @discardableResult
    @inlinable
    public mutating func writeWithUnsafeMutableBytes(_ body: (UnsafeMutableRawBufferPointer) throws -> Int) rethrows -> Int {
        let bytesWritten = try withUnsafeMutableWritableBytes(body)
        self._moveWriterIndex(to: self._writerIndex + _toIndex(bytesWritten))
        return bytesWritten
    }

    /// This vends a pointer to the storage of the `ByteBuffer`. It's marked as _very unsafe_ because it might contain
    /// uninitialised memory and it's undefined behaviour to read it. In most cases you should use `withUnsafeReadableBytes`.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    @inlinable
    public func withVeryUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        return try body(.init(self._slicedStorageBuffer))
    }

    /// This vends a pointer to the storage of the `ByteBuffer`. It's marked as _very unsafe_ because it might contain
    /// uninitialised memory and it's undefined behaviour to read it. In most cases you should use `withUnsafeMutableWritableBytes`.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    @inlinable
    public mutating func withVeryUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T {
        self._copyStorageAndRebaseIfNeeded() // this will trigger a CoW if necessary
        return try body(.init(self._slicedStorageBuffer))
    }

    /// Yields a buffer pointer containing this `ByteBuffer`'s readable bytes.
    ///
    /// - warning: Do not escape the pointer from the closure for later use.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes.
    /// - returns: The value returned by `fn`.
    @inlinable
    public func withUnsafeReadableBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        let readerIndex = self.readerIndex
        return try body(.init(rebasing: self._slicedStorageBuffer[readerIndex ..< readerIndex + self.readableBytes]))
    }

    /// Yields a buffer pointer containing this `ByteBuffer`'s readable bytes. You may hold a pointer to those bytes
    /// even after the closure returned iff you model the lifetime of those bytes correctly using the `Unmanaged`
    /// instance. If you don't require the pointer after the closure returns, use `withUnsafeReadableBytes`.
    ///
    /// If you escape the pointer from the closure, you _must_ call `storageManagement.retain()` to get ownership to
    /// the bytes and you also must call `storageManagement.release()` if you no longer require those bytes. Calls to
    /// `retain` and `release` must be balanced.
    ///
    /// - parameters:
    ///     - body: The closure that will accept the yielded bytes and the `storageManagement`.
    /// - returns: The value returned by `fn`.
    @inlinable
    public func withUnsafeReadableBytesWithStorageManagement<T>(_ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> T) rethrows -> T {
        let storageReference: Unmanaged<AnyObject> = Unmanaged.passUnretained(self._storage)
        let readerIndex = self.readerIndex
        return try body(.init(rebasing: self._slicedStorageBuffer[readerIndex ..< readerIndex + self.readableBytes]),
                        storageReference)
    }

    /// See `withUnsafeReadableBytesWithStorageManagement` and `withVeryUnsafeBytes`.
    @inlinable
    public func withVeryUnsafeBytesWithStorageManagement<T>(_ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> T) rethrows -> T {
        let storageReference: Unmanaged<AnyObject> = Unmanaged.passUnretained(self._storage)
        return try body(.init(self._slicedStorageBuffer), storageReference)
    }

    /// Returns a slice of size `length` bytes, starting at `index`. The `ByteBuffer` this is invoked on and the
    /// `ByteBuffer` returned will share the same underlying storage. However, the byte at `index` in this `ByteBuffer`
    /// will correspond to index `0` in the returned `ByteBuffer`.
    /// The `readerIndex` of the returned `ByteBuffer` will be `0`, the `writerIndex` will be `length`.
    ///
    /// - note: Please consider using `readSlice` which is a safer alternative that automatically maintains the
    ///         `readerIndex` and won't allow you to slice off uninitialized memory.
    /// - warning: This method allows the user to slice out any of the bytes in the `ByteBuffer`'s storage, including
    ///           _uninitialized_ ones. To use this API in a safe way the user needs to make sure all the requested
    ///           bytes have been written before and are therefore initialized. Note that bytes between (including)
    ///           `readerIndex` and (excluding) `writerIndex` are always initialized by contract and therefore must be
    ///           safe to read.
    /// - parameters:
    ///     - index: The index the requested slice starts at.
    ///     - length: The length of the requested slice.
    public func getSlice(at index: Int, length: Int) -> ByteBuffer? {
        precondition(index >= 0, "index must not be negative")
        precondition(length >= 0, "length must not be negative")
        guard index <= self.capacity - length else {
            return nil
        }
        let index = _toIndex(index)
        let length = _toCapacity(length)
        let sliceStartIndex = self._slice.lowerBound + index

        guard sliceStartIndex <= ByteBuffer.Slice.maxSupportedLowerBound else {
            // the slice's begin is past the maximum supported slice begin value (16 MiB) so the only option we have
            // is copy the slice into a fresh buffer. The slice begin will then be at index 0.
            var new = self
            new._moveWriterIndex(to: sliceStartIndex + length)
            new._moveReaderIndex(to: sliceStartIndex)
            new._copyStorageAndRebase(capacity: length, resetIndices: true)
            return new
        }
        var new = self
        new._slice = _ByteBufferSlice(sliceStartIndex ..< self._slice.lowerBound + index+length)
        new._moveReaderIndex(to: 0)
        new._moveWriterIndex(to: length)
        return new
    }

    /// Discard the bytes before the reader index. The byte at index `readerIndex` before calling this method will be
    /// at index `0` after the call returns.
    ///
    /// - returns: `true` if one or more bytes have been discarded, `false` if there are no bytes to discard.
    @discardableResult public mutating func discardReadBytes() -> Bool {
        guard self._readerIndex > 0 else {
            return false
        }

        if self._readerIndex == self._writerIndex {
            // If the whole buffer was consumed we can just reset the readerIndex and writerIndex to 0 and move on.
            self._moveWriterIndex(to: 0)
            self._moveReaderIndex(to: 0)
            return true
        }

        if isKnownUniquelyReferenced(&self._storage) {
            self._storage.bytes.advanced(by: Int(self._slice.lowerBound))
                .copyMemory(from: self._storage.bytes.advanced(by: Int(self._slice.lowerBound + self._readerIndex)),
                            byteCount: self.readableBytes)
            let indexShift = self._readerIndex
            self._moveReaderIndex(to: 0)
            self._moveWriterIndex(to: self._writerIndex - indexShift)
        } else {
            self._copyStorageAndRebase(extraCapacity: 0, resetIndices: true)
        }
        return true
    }

    /// The reader index or the number of bytes previously read from this `ByteBuffer`. `readerIndex` is `0` for a
    /// newly allocated `ByteBuffer`.
    public var readerIndex: Int {
        return Int(self._readerIndex)
    }

    /// The write index or the number of bytes previously written to this `ByteBuffer`. `writerIndex` is `0` for a
    /// newly allocated `ByteBuffer`.
    public var writerIndex: Int {
        return Int(self._writerIndex)
    }

    /// Set both reader index and writer index to `0`. This will reset the state of this `ByteBuffer` to the state
    /// of a freshly allocated one, if possible without allocations. This is the cheapest way to recycle a `ByteBuffer`
    /// for a new use-case.
    ///
    /// - note: This method will allocate if the underlying storage is referenced by another `ByteBuffer`. Even if an
    ///         allocation is necessary this will be cheaper as the copy of the storage is elided.
    public mutating func clear() {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._storage = self._storage.allocateStorage()
        }
        self._moveWriterIndex(to: 0)
        self._moveReaderIndex(to: 0)
    }
}
 */

extension ByteBuffer: CustomStringConvertible {
    /// A `String` describing this `ByteBuffer`. Example:
    ///
    ///     ByteBuffer { readerIndex: 0, writerIndex: 4, readableBytes: 4, capacity: 512, slice: 256..<768, storage: 0x0000000103001000 (1024 bytes)}
    ///
    /// The format of the description is not API.
    ///
    /// - returns: A description of this `ByteBuffer`.
    public var description: String {
        return """
        ByteBuffer { \
        readerIndex: \(self.readerIndex), \
        writerIndex: \(self.writerIndex), \
        readableBytes: \(self.readableBytes), \
        capacity: \(self.capacity), \
        slice: \(self._slice), \
        storage: \(self._guts._storage) (\(self._guts._storage.capacity) bytes)\
        }
        """
    }

    /// A `String` describing this `ByteBuffer` with some portion of the readable bytes dumped too. Example:
    ///
    ///     ByteBuffer { readerIndex: 0, writerIndex: 4, readableBytes: 4, capacity: 512, slice: 256..<768, storage: 0x0000000103001000 (1024 bytes)}
    ///     readable bytes (max 1k): [ 00 01 02 03 ]
    ///
    /// The format of the description is not API.
    ///
    /// - returns: A description of this `ByteBuffer` useful for debugging.
    public var debugDescription: String {
        return "\(self.description)\nreadable bytes (max 1k): \(self._guts.dumpBytes(slice: self._slice, offset: self.readerIndex, length: min(1024, self.readableBytes)))"
    }
}

/* change types to the user visible `Int` */
extension ByteBuffer {
    @inline(never)
    @usableFromInline
    mutating func _setSlowPath<Bytes: Sequence>(bytes: Bytes, at index: _Index) -> _Capacity where Bytes.Element == UInt8 {
        func ensureCapacityAndReturnStorageBase(capacity: Int) -> UnsafeMutablePointer<UInt8> {
            self._makeStorageUniquelyOwned(bytesAvailable: capacity, at: Int(index))
            let newBytesPtr = self.withVeryUnsafeMutableBytes { ptr in
                // yep, escaping the pointer here, naughty, naughty
                UnsafeMutableRawBufferPointer(rebasing: ptr[Int(index) ..< Int(index) + Int(capacity)])
            }
            return newBytesPtr.bindMemory(to: UInt8.self).baseAddress!
        }
        let underestimatedByteCount = bytes.underestimatedCount
        let newPastEndIndex: _Index = index + _toIndex(underestimatedByteCount)
        self._makeStorageUniquelyOwned(bytesAvailable: bytes.underestimatedCount, at: Int(index))
        
        var base = ensureCapacityAndReturnStorageBase(capacity: underestimatedByteCount)
        var (iterator, idx) = UnsafeMutableBufferPointer(start: base, count: underestimatedByteCount).initialize(from: bytes)
        assert(idx == underestimatedByteCount)
        while let b = iterator.next() {
            base = ensureCapacityAndReturnStorageBase(capacity: idx + 1)
            base[idx] = b
            idx += 1
        }
        return _toCapacity(idx)
    }
    
    @inlinable
    mutating func _set<Bytes: Sequence>(bytes: Bytes, at index: _Index) -> _Capacity where Bytes.Element == UInt8 {
        if let written = bytes.withContiguousStorageIfAvailable({ bytes in
            self._set(bytes: UnsafeRawBufferPointer(bytes), at: index)
        }) {
            // fast path, we've got access to the contiguous bytes
            return written
        } else {
            return self._setSlowPath(bytes: bytes, at: index)
        }
    }

    /// Copy `bytes` into the `ByteBuffer` at `index`.
    @discardableResult
    @inlinable
    public mutating func set(bytes: UnsafeRawBufferPointer, at index: Int) -> Int {
        self.setBytes(bytes, at: index)
        return bytes.count
    }

    /// Move the reader index forward by `offset` bytes.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The number of bytes to move the reader index forward by.
    public mutating func moveReaderIndex(forwardBy offset: Int) {
        let newIndex = self._readerIndex + _toIndex(offset)
        precondition(newIndex >= 0 && newIndex <= writerIndex, "new readerIndex: \(newIndex), expected: range(0, \(writerIndex))")
        self._moveReaderIndex(to: newIndex)
    }

    /// Set the reader index to `offset`.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The offset in bytes to set the reader index to.
    public mutating func moveReaderIndex(to offset: Int) {
        let newIndex = _toIndex(offset)
        precondition(newIndex >= 0 && newIndex <= writerIndex, "new readerIndex: \(newIndex), expected: range(0, \(writerIndex))")
        self._moveReaderIndex(to: newIndex)
    }

    /// Move the writer index forward by `offset` bytes.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The number of bytes to move the writer index forward by.
    public mutating func moveWriterIndex(forwardBy offset: Int) {
        let newIndex = self._writerIndex + _toIndex(offset)
        precondition(newIndex >= 0 && newIndex <= _toCapacity(self._slice.count),"new writerIndex: \(newIndex), expected: range(0, \(_toCapacity(self._slice.count)))")
        self._moveWriterIndex(to: newIndex)
    }

    /// Set the writer index to `offset`.
    ///
    /// - warning: By contract the bytes between (including) `readerIndex` and (excluding) `writerIndex` must be
    ///            initialised, ie. have been written before. Also the `readerIndex` must always be less than or equal
    ///            to the `writerIndex`. Failing to meet either of these requirements leads to undefined behaviour.
    /// - parameters:
    ///   - offset: The offset in bytes to set the reader index to.
    public mutating func moveWriterIndex(to offset: Int) {
        let newIndex = _toIndex(offset)
        precondition(newIndex >= 0 && newIndex <= _toCapacity(self._slice.count),"new writerIndex: \(newIndex), expected: range(0, \(_toCapacity(self._slice.count)))")
        self._moveWriterIndex(to: newIndex)
    }
}

extension ByteBuffer: Equatable {
    // TODO: I don't think this makes sense. This should compare bytes 0..<writerIndex instead.

    /// Compare two `ByteBuffer` values. Two `ByteBuffer` values are considered equal if the readable bytes are equal.
    public static func ==(lhs: ByteBuffer, rhs: ByteBuffer) -> Bool {
        guard lhs.readableBytes == rhs.readableBytes else {
            return false
        }

        if lhs._slice == rhs._slice && lhs._guts._storage === rhs._guts._storage {
            return true
        }

        return lhs.withUnsafeReadableBytes { lPtr in
            rhs.withUnsafeReadableBytes { rPtr in
                // Shouldn't get here otherwise because of readableBytes check
                assert(lPtr.count == rPtr.count)
                return memcmp(lPtr.baseAddress!, rPtr.baseAddress!, lPtr.count) == 0
            }
        }
    }
}
