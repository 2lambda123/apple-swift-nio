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

import Dispatch
import Foundation
import NIO
import NIOFoundationCompat
import NIOHTTP1
import NIOTLS
import NIOWebSocket

// This is NIO 2's 'NIO1 API Shims' module.
//
// Please note that _NIO1APIShimsHelpers is a transitional module that is untested and
// is not part of the public API. Before NIO 2.0.0 gets released it's still very useful
// to `import _NIO1APIShimsHelpers` because it will make it easier for you to keep up
// with NIO2 API changes until the API will stabilise and we will start tagging versions.
//
// Please do not depend on this module in tagged versions.
//
//   💜 the SwiftNIO team.

@available(*, deprecated, message: "ContiguousCollection does not exist in NIO2")
public protocol ContiguousCollection: Collection {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}

@available(*, deprecated, renamed: "SNIResult")
public typealias SniResult = SNIResult

@available(*, deprecated, renamed: "SNIHandler")
public typealias SniHandler = SNIHandler

@available(*, deprecated, renamed: "NIOFileHandle")
public typealias FileHandle = NIOFileHandle

@available(*, deprecated, message: "don't use the StaticString: Collection extension please")
extension StaticString: Collection {
    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public typealias Element = UInt8
    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public typealias SubSequence = ArraySlice<UInt8>

    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public typealias _Index = Int

    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public var startIndex: _Index { 0 }
    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public var endIndex: _Index { utf8CodeUnitCount }
    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public func index(after i: _Index) -> _Index { i + 1 }

    @available(*, deprecated, message: "don't use the StaticString: Collection extension please")
    public subscript(position: Int) -> UInt8 {
        precondition(position < utf8CodeUnitCount, "index \(position) out of bounds")
        return utf8Start.advanced(by: position).pointee
    }
}

public extension ChannelPipeline {
    @available(*, deprecated, message: "please use addHandler(ByteToMessageHandler(myByteToMessageDecoder))")
    func add<Decoder: ByteToMessageDecoder>(handler decoder: Decoder) -> EventLoopFuture<Void> {
        addHandler(ByteToMessageHandler(decoder))
    }

    @available(*, deprecated, message: "please use addHandler(MessageToByteHandler(myMessageToByteEncoder))")
    func add<Encoder: MessageToByteEncoder>(handler encoder: Encoder) -> EventLoopFuture<Void> {
        addHandler(MessageToByteHandler(encoder))
    }

    @available(*, deprecated, renamed: "addHandler(_:position:)")
    func add(handler: ChannelHandler, first: Bool = false) -> EventLoopFuture<Void> {
        addHandler(handler, position: first ? .first : .last)
    }

    @available(*, deprecated, renamed: "addHandler(_:name:position:)")
    func add(name: String, handler: ChannelHandler, first: Bool = false) -> EventLoopFuture<Void> {
        addHandler(handler, name: name, position: first ? .first : .last)
    }

    @available(*, deprecated, renamed: "addHandler(_:name:position:)")
    func add(name: String? = nil, handler: ChannelHandler, after: ChannelHandler) -> EventLoopFuture<Void> {
        addHandler(handler, name: name, position: .after(after))
    }

    @available(*, deprecated, renamed: "addHandler(_:name:position:)")
    func add(name: String? = nil, handler: ChannelHandler, before: ChannelHandler) -> EventLoopFuture<Void> {
        addHandler(handler, name: name, position: .before(before))
    }

    @available(*, deprecated, renamed: "removeHandler(_:)")
    func remove(handler: RemovableChannelHandler) -> EventLoopFuture<Void> {
        removeHandler(handler)
    }

    @available(*, deprecated, renamed: "removeHandler(name:)")
    func remove(name: String) -> EventLoopFuture<Void> {
        removeHandler(name: name)
    }

    @available(*, deprecated, renamed: "removeHandler(context:)")
    func remove(context: ChannelHandlerContext) -> EventLoopFuture<Void> {
        removeHandler(context: context)
    }

    @available(*, deprecated, renamed: "removeHandler(_:promise:)")
    func remove(handler: RemovableChannelHandler, promise: EventLoopPromise<Void>?) {
        removeHandler(handler, promise: promise)
    }

    @available(*, deprecated, renamed: "removeHandler(name:promise:)")
    func remove(name: String, promise: EventLoopPromise<Void>?) {
        removeHandler(name: name, promise: promise)
    }

    @available(*, deprecated, renamed: "removeHandler(context:promise:)")
    func remove(context: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        removeHandler(context: context, promise: promise)
    }
}

public extension EventLoop {
    @available(*, deprecated, renamed: "makePromise")
    func newPromise<T>(of type: T.Type = T.self, file: StaticString = #file, line: UInt = #line) -> EventLoopPromise<T> {
        makePromise(of: type, file: file, line: line)
    }

    @available(*, deprecated, renamed: "makeSucceededFuture(_:)")
    func newSucceededFuture<T>(result: T) -> EventLoopFuture<T> {
        makeSucceededFuture(result)
    }

    @available(*, deprecated, renamed: "makeFailedFuture(_:)")
    func newFailedFuture<T>(error: Error) -> EventLoopFuture<T> {
        makeFailedFuture(error)
    }

    @available(*, deprecated, renamed: "scheduleRepeatedAsyncTask")
    func scheduleRepeatedTask(initialDelay: TimeAmount,
                              delay: TimeAmount,
                              notifying _: EventLoopPromise<Void>? = nil,
                              _ task: @escaping (RepeatedTask) -> EventLoopFuture<Void>) -> RepeatedTask
    {
        scheduleRepeatedAsyncTask(initialDelay: initialDelay, delay: delay, task)
    }
}

public extension EventLoopFuture {
    @available(*, deprecated, renamed: "Value")
    typealias T = Value

    @available(*, deprecated, message: "whenComplete now gets Result<Value, Error>")
    func whenComplete(_ body: @escaping () -> Void) {
        whenComplete { (_: Result) in
            body()
        }
    }

    @available(*, deprecated, renamed: "flatMap")
    func then<U>(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Value) -> EventLoopFuture<U>) -> EventLoopFuture<U> {
        flatMap(file: file, line: line, callback)
    }

    @available(*, deprecated, renamed: "flatMapThrowing")
    func thenThrowing<U>(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Value) throws -> U) -> EventLoopFuture<U> {
        flatMapThrowing(file: file, line: line, callback)
    }

    @available(*, deprecated, renamed: "flatMapError")
    func thenIfError(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Error) -> EventLoopFuture<Value>) -> EventLoopFuture<Value> {
        flatMapError(file: file, line: line, callback)
    }

    @available(*, deprecated, renamed: "flatMapErrorThrowing")
    func thenIfErrorThrowing(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Error) throws -> Value) -> EventLoopFuture<Value> {
        flatMapErrorThrowing(file: file, line: line, callback)
    }

    @available(*, deprecated, renamed: "recover")
    func mapIfError(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (Error) -> Value) -> EventLoopFuture<Value> {
        recover(file: file, line: line, callback)
    }

    @available(*, deprecated, renamed: "and(value:file:line:)")
    func and<OtherValue>(result: OtherValue,
                         file: StaticString = #file,
                         line: UInt = #line) -> EventLoopFuture<(Value, OtherValue)>
    {
        and(value: result, file: file, line: line)
    }

    @available(*, deprecated, renamed: "cascade(to:)")
    func cascade(promise: EventLoopPromise<Value>?) {
        cascade(to: promise)
    }

    @available(*, deprecated, renamed: "cascadeFailure(to:)")
    func cascadeFailure<NewValue>(promise: EventLoopPromise<NewValue>?) {
        cascadeFailure(to: promise)
    }

    @available(*, deprecated, renamed: "andAllSucceed(_:on:)")
    static func andAll(_ futures: [EventLoopFuture<Void>], eventLoop: EventLoop) -> EventLoopFuture<Void> {
        .andAllSucceed(futures, on: eventLoop)
    }

    @available(*, deprecated, renamed: "hop(to:)")
    func hopTo(eventLoop: EventLoop) -> EventLoopFuture<Value> {
        hop(to: eventLoop)
    }

    @available(*, deprecated, renamed: "reduce(_:_:on:_:)")
    static func reduce<InputValue>(_ initialResult: Value,
                                   _ futures: [EventLoopFuture<InputValue>],
                                   eventLoop: EventLoop,
                                   _ nextPartialResult: @escaping (Value, InputValue) -> Value) -> EventLoopFuture<Value>
    {
        .reduce(initialResult, futures, on: eventLoop, nextPartialResult)
    }

    @available(*, deprecated, renamed: "reduce(into:_:on:_:)")
    static func reduce<InputValue>(into initialResult: Value,
                                   _ futures: [EventLoopFuture<InputValue>],
                                   eventLoop: EventLoop,
                                   _ updateAccumulatingResult: @escaping (inout Value, InputValue) -> Void) -> EventLoopFuture<Value>
    {
        .reduce(into: initialResult, futures, on: eventLoop, updateAccumulatingResult)
    }
}

public extension EventLoopPromise {
    @available(*, deprecated, renamed: "succeed(_:)")
    func succeed(result: Value) {
        succeed(result)
    }

    @available(*, deprecated, renamed: "fail(_:)")
    func fail(error: Error) {
        fail(error)
    }
}

public extension EventLoopGroup {
    @available(*, deprecated, message: "makeIterator is now required")
    func makeIterator() -> NIO.EventLoopIterator {
        .init([])
    }
}

public extension MarkedCircularBuffer {
    @available(*, deprecated, renamed: "Element")
    typealias E = Element

    internal func _makeIndex(value: Int) -> Index {
        index(startIndex, offsetBy: value)
    }

    @available(*, deprecated, renamed: "init(initialCapacity:)")
    init(initialRingCapacity: Int) {
        self = .init(initialCapacity: initialRingCapacity)
    }

    @available(*, deprecated, message: "please use MarkedCircularBuffer.Index instead of Int")
    func index(after i: Int) -> Int {
        i + 1
    }

    @available(*, deprecated, message: "please use MarkedCircularBuffer.Index instead of Int")
    func index(before: Int) -> Int {
        before - 1
    }

    @available(*, deprecated, message: "please use MarkedCircularBuffer.Index instead of Int")
    func isMarked(index: Int) -> Bool {
        isMarked(index: _makeIndex(value: index))
    }

    @available(*, deprecated, message: "hasMark is now a property, remove `()`")
    func hasMark() -> Bool {
        hasMark
    }

    @available(*, deprecated, message: "markedElement is now a property, remove `()`")
    func markedElement() -> E? {
        markedElement
    }

    @available(*, deprecated, message: "markedElementIndex is now a property, remove `()`")
    func markedElementIndex() -> Index? {
        markedElementIndex
    }
}

public extension HTTPVersion {
    @available(*, deprecated, message: "type of major and minor is now Int")
    init(major: UInt16, minor: UInt16) {
        self = .init(major: Int(major), minor: Int(minor))
    }

    @available(*, deprecated, message: "type of major is now Int")
    var majorLegacy: UInt16 {
        UInt16(major)
    }

    @available(*, deprecated, message: "type of minor is now Int")
    var minorLegacy: UInt16 {
        UInt16(minor)
    }
}

public extension HTTPHeaders {
    @available(*, deprecated, message: "don't pass ByteBufferAllocator anymore")
    init(_ headers: [(String, String)] = [], allocator _: ByteBufferAllocator) {
        self.init(headers)
    }
}

@available(*, deprecated, renamed: "ChannelError")
public enum ChannelLifecycleError {
    @available(*, deprecated, message: "ChannelLifecycleError values are now available on ChannelError")
    public static var inappropriateOperationForState: ChannelError {
        ChannelError.inappropriateOperationForState
    }
}

@available(*, deprecated, renamed: "ChannelError")
public enum MulticastError {
    @available(*, deprecated, message: "MulticastError values are now available on ChannelError")
    public static var unknownLocalAddress: ChannelError {
        .unknownLocalAddress
    }

    @available(*, deprecated, message: "MulticastError values are now available on ChannelError")
    public static var badMulticastGroupAddressFamily: ChannelError {
        .badMulticastGroupAddressFamily
    }

    @available(*, deprecated, message: "MulticastError values are now available on ChannelError")
    public static var badInterfaceAddressFamily: ChannelError {
        .badInterfaceAddressFamily
    }

    @available(*, deprecated, message: "MulticastError values are now available on ChannelError")
    public static func illegalMulticastAddress(_ address: SocketAddress) -> ChannelError {
        .illegalMulticastAddress(address)
    }
}

public extension ChannelError {
    @available(*, deprecated, message: "ChannelError.connectFailed has been removed")
    static var connectFailed: NIOConnectionError {
        fatalError("ChannelError.connectFailed has been removed in NIO2")
    }
}

public extension SocketAddress {
    @available(*, deprecated, message: "type of port is now Int?")
    var portLegacy: UInt16? {
        port.map(UInt16.init)
    }

    @available(*, deprecated, renamed: "makeAddressResolvingHost")
    static func newAddressResolving(host: String, port: Int) throws -> SocketAddress {
        try makeAddressResolvingHost(host, port: port)
    }
}

public extension CircularBuffer {
    internal func _makeIndex(value: Int) -> Index {
        index(startIndex, offsetBy: value)
    }

    @available(*, deprecated, renamed: "Element")
    typealias E = Element

    @available(*, deprecated, renamed: "init(initialCapacity:)")
    init(initialRingCapacity: Int) {
        self = .init(initialCapacity: initialRingCapacity)
    }

    @available(*, deprecated, message: "please use CircularBuffer.Index instead of Int")
    subscript(index: Int) -> E {
        self[_makeIndex(value: index)]
    }

    @available(*, deprecated, message: "please use CircularBuffer.Index instead of Int")
    func index(after: Int) -> Int {
        after + 1
    }

    @available(*, deprecated, message: "please use CircularBuffer.Index instead of Int")
    func index(before: Int) -> Int {
        before - 1
    }

    @available(*, deprecated, message: "please use CircularBuffer.Index instead of Int")
    mutating func removeSubrange(_ bounds: Range<Int>) {
        removeSubrange(_makeIndex(value: bounds.lowerBound) ..< _makeIndex(value: bounds.upperBound))
    }

    @available(*, deprecated, message: "please use CircularBuffer.Index instead of Int")
    mutating func remove(at position: Int) -> E {
        remove(at: _makeIndex(value: position))
    }
}

public extension ByteBuffer {
    @available(*, deprecated, renamed: "writeStaticString(_:)")
    mutating func write(staticString: StaticString) -> Int {
        writeStaticString(staticString)
    }

    @available(*, deprecated, renamed: "setStaticString(_:at:)")
    mutating func set(staticString: StaticString, at index: Int) -> Int {
        setStaticString(staticString, at: index)
    }

    @available(*, deprecated, renamed: "writeString(_:)")
    mutating func write(string: String) -> Int {
        writeString(string)
    }

    @available(*, deprecated, renamed: "setString(_:at:)")
    mutating func set(string: String, at index: Int) -> Int {
        setString(string, at: index)
    }

    @available(*, deprecated, renamed: "writeDispatchData(_:)")
    mutating func write(dispatchData: DispatchData) -> Int {
        writeDispatchData(dispatchData)
    }

    @available(*, deprecated, renamed: "setDispatchData(_:)")
    mutating func set(dispatchData: DispatchData, at index: Int) -> Int {
        setDispatchData(dispatchData, at: index)
    }

    @available(*, deprecated, renamed: "writeBuffer(_:)")
    mutating func write(buffer: inout ByteBuffer) -> Int {
        writeBuffer(&buffer)
    }

    @available(*, deprecated, renamed: "writeBytes(_:)")
    mutating func write<Bytes: Sequence>(bytes: Bytes) -> Int where Bytes.Element == UInt8 {
        writeBytes(bytes)
    }

    @available(*, deprecated, renamed: "writeBytes(_:)")
    mutating func write(bytes: UnsafeRawBufferPointer) -> Int {
        writeBytes(bytes)
    }

    @available(*, deprecated, renamed: "setBytes(at:)")
    mutating func set<Bytes: Sequence>(bytes: Bytes, at index: Int) -> Int where Bytes.Element == UInt8 {
        setBytes(bytes, at: index)
    }

    @available(*, deprecated, renamed: "setBytes(at:)")
    mutating func set(bytes: UnsafeRawBufferPointer, at index: Int) -> Int {
        setBytes(bytes, at: index)
    }

    @available(*, deprecated, renamed: "writeInteger(_:endianness:as:)")
    mutating func write<T: FixedWidthInteger>(integer: T, endianness: Endianness = .big, as type: T.Type = T.self) -> Int {
        writeInteger(integer, endianness: endianness, as: type)
    }

    @available(*, deprecated, renamed: "setInteger(_:at:endianness:as:)")
    mutating func set<T: FixedWidthInteger>(integer: T, at index: Int, endianness: Endianness = .big, as type: T.Type = T.self) -> Int {
        setInteger(integer, at: index, endianness: endianness, as: type)
    }

    @available(*, deprecated, renamed: "writeString(_:encoding:)")
    mutating func write(string: String, encoding: String.Encoding) throws -> Int {
        try writeString(string, encoding: encoding)
    }

    @available(*, deprecated, renamed: "setString(_:encoding:at:)")
    mutating func set(string: String, encoding: String.Encoding, at index: Int) throws -> Int {
        try setString(string, encoding: encoding, at: index)
    }
}

public extension Channel {
    @available(*, deprecated, renamed: "_channelCore")
    var _unsafe: ChannelCore {
        _channelCore
    }

    @available(*, deprecated, renamed: "setOption(_:value:)")
    func setOption<Option: ChannelOption>(option: Option, value: Option.Value) -> EventLoopFuture<Void> {
        setOption(option, value: value)
    }

    @available(*, deprecated, renamed: "getOption(_:)")
    func getOption<Option: ChannelOption>(option: Option) -> EventLoopFuture<Option.Value> {
        getOption(option)
    }
}

public extension ChannelOption {
    @available(*, deprecated, renamed: "Value")
    typealias OptionType = Value
}

@available(*, deprecated, renamed: "HTTPServerProtocolUpgrader")
public typealias HTTPProtocolUpgrader = HTTPServerProtocolUpgrader

@available(*, deprecated, renamed: "HTTPServerUpgradeEvents")
public typealias HTTPUpgradeEvents = HTTPServerUpgradeEvents

@available(*, deprecated, renamed: "HTTPServerUpgradeErrors")
public typealias HTTPUpgradeErrors = HTTPServerUpgradeErrors

@available(*, deprecated, renamed: "NIOThreadPool")
public typealias BlockingIOThreadPool = NIOThreadPool

public extension WebSocketFrameDecoder {
    @available(*, deprecated, message: "automaticErrorHandling deprecated, use WebSocketProtocolErrorHandler instead")
    convenience init(maxFrameSize: Int = 1 << 14, automaticErrorHandling _: Bool) {
        self.init(maxFrameSize: maxFrameSize)
    }
}
