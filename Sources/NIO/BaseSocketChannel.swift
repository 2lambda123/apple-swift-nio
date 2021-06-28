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

import NIOConcurrencyHelpers

private struct SocketChannelLifecycleManager {
    // MARK: Types

    private enum State {
        case fresh
        case preRegistered // register() has been run but the selector doesn't know about it yet
        case fullyRegistered // fully registered, ie. the selector knows about it
        case activated
        case closed
    }

    private enum Event {
        case activate
        case beginRegistration
        case finishRegistration
        case close
    }

    // MARK: properties

    private let eventLoop: EventLoop
    // this is queried from the Channel, ie. must be thread-safe
    internal let isActiveAtomic: NIOAtomic<Bool>
    // these are only to be accessed on the EventLoop

    // have we seen the `.readEOF` notification
    // note: this can be `false` on a deactivated channel, we might just have torn it down.
    var hasSeenEOFNotification: Bool = false

    private var currentState: State = .fresh {
        didSet {
            eventLoop.assertInEventLoop()
            switch (oldValue, currentState) {
            case (_, .activated):
                isActiveAtomic.store(true)
            case (.activated, _):
                isActiveAtomic.store(false)
            default:
                ()
            }
        }
    }

    // MARK: API

    // isActiveAtomic needs to be injected as it's accessed from arbitrary threads and `SocketChannelLifecycleManager` is usually held mutable
    internal init(eventLoop: EventLoop, isActiveAtomic: NIOAtomic<Bool>) {
        self.eventLoop = eventLoop
        self.isActiveAtomic = isActiveAtomic
    }

    // this is called from Channel's deinit, so don't assert we're on the EventLoop!
    internal var canBeDestroyed: Bool {
        currentState == .closed
    }

    @inline(__always) // we need to return a closure here and to not suffer from a potential allocation for that this must be inlined
    internal mutating func beginRegistration() -> ((EventLoopPromise<Void>?, ChannelPipeline) -> Void) {
        return moveState(event: .beginRegistration)
    }

    @inline(__always) // we need to return a closure here and to not suffer from a potential allocation for that this must be inlined
    internal mutating func finishRegistration() -> ((EventLoopPromise<Void>?, ChannelPipeline) -> Void) {
        return moveState(event: .finishRegistration)
    }

    @inline(__always) // we need to return a closure here and to not suffer from a potential allocation for that this must be inlined
    internal mutating func close() -> ((EventLoopPromise<Void>?, ChannelPipeline) -> Void) {
        return moveState(event: .close)
    }

    @inline(__always) // we need to return a closure here and to not suffer from a potential allocation for that this must be inlined
    internal mutating func activate() -> ((EventLoopPromise<Void>?, ChannelPipeline) -> Void) {
        return moveState(event: .activate)
    }

    // MARK: private API

    @inline(__always) // we need to return a closure here and to not suffer from a potential allocation for that this must be inlined
    private mutating func moveState(event: Event) -> ((EventLoopPromise<Void>?, ChannelPipeline) -> Void) {
        eventLoop.assertInEventLoop()

        switch (currentState, event) {
        // origin: .fresh
        case (.fresh, .beginRegistration):
            currentState = .preRegistered
            return { promise, pipeline in
                promise?.succeed(())
                pipeline.fireChannelRegistered0()
            }

        case (.fresh, .close):
            currentState = .closed
            return { (promise, _: ChannelPipeline) in
                promise?.succeed(())
            }

        // origin: .preRegistered
        case (.preRegistered, .finishRegistration):
            currentState = .fullyRegistered
            return { (promise, _: ChannelPipeline) in
                promise?.succeed(())
            }

        // origin: .fullyRegistered
        case (.fullyRegistered, .activate):
            currentState = .activated
            return { promise, pipeline in
                promise?.succeed(())
                pipeline.fireChannelActive0()
            }

        // origin: .preRegistered || .fullyRegistered
        case (.preRegistered, .close), (.fullyRegistered, .close):
            currentState = .closed
            return { promise, pipeline in
                promise?.succeed(())
                pipeline.fireChannelUnregistered0()
            }

        // origin: .activated
        case (.activated, .close):
            currentState = .closed
            return { promise, pipeline in
                promise?.succeed(())
                pipeline.fireChannelInactive0()
                pipeline.fireChannelUnregistered0()
            }

        // bad transitions
        case (.fresh, .activate), // should go through .registered first
             (.preRegistered, .activate), // need to first be fully registered
             (.preRegistered, .beginRegistration), // already registered
             (.fullyRegistered, .beginRegistration), // already registered
             (.activated, .activate), // already activated
             (.activated, .beginRegistration), // already fully registered (and activated)
             (.activated, .finishRegistration), // already fully registered (and activated)
             (.fullyRegistered, .finishRegistration), // already fully registered
             (.fresh, .finishRegistration), // need to register lazily first
             (.closed, _): // already closed
            badTransition(event: event)
        }
    }

    private func badTransition(event: Event) -> Never {
        preconditionFailure("illegal transition: state=\(currentState), event=\(event)")
    }

    // MARK: convenience properties

    internal var isActive: Bool {
        eventLoop.assertInEventLoop()
        return currentState == .activated
    }

    internal var isPreRegistered: Bool {
        eventLoop.assertInEventLoop()
        switch currentState {
        case .fresh, .closed:
            return false
        case .preRegistered, .fullyRegistered, .activated:
            return true
        }
    }

    internal var isRegisteredFully: Bool {
        eventLoop.assertInEventLoop()
        switch currentState {
        case .fresh, .closed, .preRegistered:
            return false
        case .fullyRegistered, .activated:
            return true
        }
    }

    /// Returns whether the underlying file descriptor is open. This property will always be true (even before registration)
    /// until the Channel is closed.
    internal var isOpen: Bool {
        eventLoop.assertInEventLoop()
        return currentState != .closed
    }
}

/// The base class for all socket-based channels in NIO.
///
/// There are many types of specialised socket-based channel in NIO. Each of these
/// has different logic regarding how exactly they read from and write to the network.
/// However, they share a great deal of common logic around the managing of their
/// file descriptors.
///
/// For this reason, `BaseSocketChannel` exists to provide a common core implementation of
/// the `SelectableChannel` protocol. It uses a number of private functions to provide hooks
/// for subclasses to implement the specific logic to handle their writes and reads.
class BaseSocketChannel<SocketType: BaseSocketProtocol>: SelectableChannel, ChannelCore {
    typealias SelectableType = SocketType.SelectableType

    struct AddressCache {
        // deliberately lets because they must always be updated together (so forcing `init` is useful).
        let local: SocketAddress?
        let remote: SocketAddress?

        init(local: SocketAddress?, remote: SocketAddress?) {
            self.local = local
            self.remote = remote
        }
    }

    // MARK: - Stored Properties

    // MARK: Constants & atomics (accessible everywhere)

    public let parent: Channel?
    internal let socket: SocketType
    private let closePromise: EventLoopPromise<Void>
    internal let selectableEventLoop: SelectableEventLoop
    private let _offEventLoopLock = Lock()
    private let isActiveAtomic: NIOAtomic<Bool> = .makeAtomic(value: false)
    // just a thread-safe way of having something to print about the socket from any thread
    internal let socketDescription: String

    // MARK: Variables, on EventLoop thread only

    var readPending = false
    var pendingConnect: EventLoopPromise<Void>?
    var recvAllocator: RecvByteBufferAllocator
    var maxMessagesPerRead: UInt = 4
    private var inFlushNow: Bool = false // Guard against re-entrance of flushNow() method.
    private var autoRead: Bool = true

    // MARK: Variables that are really constants

    private var _pipeline: ChannelPipeline! // this is really a constant (set in .init) but needs `self` to be constructed and therefore a `var`. Do not change as this needs to accessed from arbitrary threads

    // MARK: Special variables, please read comments.

    // For reads guarded by _either_ `self._offEventLoopLock` or the EL thread
    // Writes are guarded by _offEventLoopLock _and_ the EL thread.
    // PLEASE don't use these directly and use the non-underscored computed properties instead.
    private var _addressCache = AddressCache(local: nil, remote: nil) // please use `self.addressesCached` instead
    private var _bufferAllocatorCache: ByteBufferAllocator // please use `self.bufferAllocatorCached` instead.

    // MARK: - Computed properties

    // This is called from arbitrary threads.
    internal var addressesCached: AddressCache {
        get {
            if eventLoop.inEventLoop {
                return _addressCache
            } else {
                return _offEventLoopLock.withLock {
                    return self._addressCache
                }
            }
        }
        set {
            eventLoop.preconditionInEventLoop()
            _offEventLoopLock.withLock {
                self._addressCache = newValue
            }
        }
    }

    // This is called from arbitrary threads.
    private var bufferAllocatorCached: ByteBufferAllocator {
        get {
            if eventLoop.inEventLoop {
                return _bufferAllocatorCache
            } else {
                return _offEventLoopLock.withLock {
                    return self._bufferAllocatorCache
                }
            }
        }
        set {
            eventLoop.preconditionInEventLoop()
            _offEventLoopLock.withLock {
                self._bufferAllocatorCache = newValue
            }
        }
    }

    // We start with the invalid empty set of selector events we're interested in. This is to make sure we later on
    // (in `becomeFullyRegistered0`) seed the initial event correctly.
    internal var interestedEvent: SelectorEventSet = [] {
        didSet {
            assert(interestedEvent.contains(.reset), "impossible to unregister for reset")
        }
    }

    private var lifecycleManager: SocketChannelLifecycleManager {
        didSet {
            eventLoop.assertInEventLoop()
        }
    }

    private var bufferAllocator = ByteBufferAllocator() {
        didSet {
            eventLoop.assertInEventLoop()
            bufferAllocatorCached = bufferAllocator
        }
    }

    public final var _channelCore: ChannelCore { self }

    // This is `Channel` API so must be thread-safe.
    public final var localAddress: SocketAddress? {
        addressesCached.local
    }

    // This is `Channel` API so must be thread-safe.
    public final var remoteAddress: SocketAddress? {
        addressesCached.remote
    }

    /// `false` if the whole `Channel` is closed and so no more IO operation can be done.
    var isOpen: Bool {
        eventLoop.assertInEventLoop()
        return lifecycleManager.isOpen
    }

    var isRegistered: Bool {
        eventLoop.assertInEventLoop()
        return lifecycleManager.isPreRegistered
    }

    // This is `Channel` API so must be thread-safe.
    public var isActive: Bool {
        isActiveAtomic.load()
    }

    // This is `Channel` API so must be thread-safe.
    public final var closeFuture: EventLoopFuture<Void> {
        closePromise.futureResult
    }

    public final var eventLoop: EventLoop {
        selectableEventLoop
    }

    // This is `Channel` API so must be thread-safe.
    public var isWritable: Bool {
        true
    }

    // This is `Channel` API so must be thread-safe.
    public final var allocator: ByteBufferAllocator {
        bufferAllocatorCached
    }

    // This is `Channel` API so must be thread-safe.
    public final var pipeline: ChannelPipeline {
        _pipeline
    }

    // MARK: Methods to override in subclasses.

    func writeToSocket() throws -> OverallWriteResult {
        fatalError("must be overridden")
    }

    /// Read data from the underlying socket and dispatch it to the `ChannelPipeline`
    ///
    /// - returns: `true` if any data was read, `false` otherwise.
    @discardableResult func readFromSocket() throws -> ReadResult {
        fatalError("this must be overridden by sub class")
    }

    // MARK: - Datatypes

    /// Indicates if a selectable should registered or not for IO notifications.
    enum IONotificationState {
        /// We should be registered for IO notifications.
        case register

        /// We should not be registered for IO notifications.
        case unregister
    }

    enum ReadResult {
        /// Nothing was read by the read operation.
        case none

        /// Some data was read by the read operation.
        case some
    }

    /// Returned by the `private func readable0()` to inform the caller about the current state of the underlying read stream.
    /// This is mostly useful when receiving `.readEOF` as we then need to drain the read stream fully (ie. until we receive EOF or error of course)
    private enum ReadStreamState: Equatable {
        /// Everything seems normal
        case normal(ReadResult)

        /// We saw EOF.
        case eof

        /// A read error was received.
        case error
    }

    /// Begin connection of the underlying socket.
    ///
    /// - parameters:
    ///     - to: The `SocketAddress` to connect to.
    /// - returns: `true` if the socket connected synchronously, `false` otherwise.
    func connectSocket(to _: SocketAddress) throws -> Bool {
        fatalError("this must be overridden by sub class")
    }

    /// Make any state changes needed to complete the connection process.
    func finishConnectSocket() throws {
        fatalError("this must be overridden by sub class")
    }

    /// Returns if there are any flushed, pending writes to be sent over the network.
    func hasFlushedPendingWrites() -> Bool {
        fatalError("this must be overridden by sub class")
    }

    /// Buffer a write in preparation for a flush.
    func bufferPendingWrite(data _: NIOAny, promise _: EventLoopPromise<Void>?) {
        fatalError("this must be overridden by sub class")
    }

    /// Mark a flush point. This is called when flush is received, and instructs
    /// the implementation to record the flush.
    func markFlushPoint() {
        fatalError("this must be overridden by sub class")
    }

    /// Called when closing, to instruct the specific implementation to discard all pending
    /// writes.
    func cancelWritesOnClose(error _: Error) {
        fatalError("this must be overridden by sub class")
    }

    // MARK: Common base socket logic.

    init(socket: SocketType, parent: Channel?, eventLoop: SelectableEventLoop, recvAllocator: RecvByteBufferAllocator) throws {
        _bufferAllocatorCache = bufferAllocator
        self.socket = socket
        selectableEventLoop = eventLoop
        closePromise = eventLoop.makePromise()
        self.parent = parent
        self.recvAllocator = recvAllocator
        // As the socket may already be connected we should ensure we start with the correct addresses cached.
        _addressCache = .init(local: try? socket.localAddress(), remote: try? socket.remoteAddress())
        lifecycleManager = SocketChannelLifecycleManager(eventLoop: eventLoop, isActiveAtomic: isActiveAtomic)
        socketDescription = socket.description
        pendingConnect = nil
        _pipeline = ChannelPipeline(channel: self)
    }

    deinit {
        assert(self.lifecycleManager.canBeDestroyed,
               "leak of open Channel, state: \(String(describing: self.lifecycleManager))")
    }

    public final func localAddress0() throws -> SocketAddress {
        eventLoop.assertInEventLoop()
        guard isOpen else {
            throw ChannelError.ioOnClosedChannel
        }
        return try socket.localAddress()
    }

    public final func remoteAddress0() throws -> SocketAddress {
        eventLoop.assertInEventLoop()
        guard isOpen else {
            throw ChannelError.ioOnClosedChannel
        }
        return try socket.remoteAddress()
    }

    /// Flush data to the underlying socket and return if this socket needs to be registered for write notifications.
    ///
    /// This method can be called re-entrantly but it will return immediately because the first call is responsible
    /// for sending all flushed writes, even the ones that are accumulated whilst `flushNow()` is running.
    ///
    /// - returns: If this socket should be registered for write notifications. Ie. `IONotificationState.register` if
    ///            _not_ all data could be written, so notifications are necessary; and `IONotificationState.unregister`
    ///             if everything was written and we don't need to be notified about writability at the moment.
    func flushNow() -> IONotificationState {
        eventLoop.assertInEventLoop()

        // Guard against re-entry as data that will be put into `pendingWrites` will just be picked up by
        // `writeToSocket`.
        guard !inFlushNow else {
            return .unregister
        }

        assert(!inFlushNow)
        inFlushNow = true
        defer {
            self.inFlushNow = false
        }

        var newWriteRegistrationState: IONotificationState = .unregister
        do {
            while newWriteRegistrationState == .unregister, hasFlushedPendingWrites(), isOpen {
                assert(lifecycleManager.isActive)
                let writeResult = try writeToSocket()
                switch writeResult.writeResult {
                case .couldNotWriteEverything:
                    newWriteRegistrationState = .register
                case .writtenCompletely:
                    newWriteRegistrationState = .unregister
                }

                if writeResult.writabilityChange {
                    // We went from not writable to writable.
                    pipeline.fireChannelWritabilityChanged0()
                }
            }
        } catch let err {
            // If there is a write error we should try drain the inbound before closing the socket as there may be some data pending.
            // We ignore any error that is thrown as we will use the original err to close the channel and notify the user.
            if self.readIfNeeded0() {
                assert(self.lifecycleManager.isActive)

                // We need to continue reading until there is nothing more to be read from the socket as we will not have another chance to drain it.
                var readAtLeastOnce = false
                while let read = try? self.readFromSocket(), read == .some {
                    readAtLeastOnce = true
                }
                if readAtLeastOnce, self.lifecycleManager.isActive {
                    self.pipeline.fireChannelReadComplete()
                }
            }

            self.close0(error: err, mode: .all, promise: nil)

            // we handled all writes
            return .unregister
        }

        assert((newWriteRegistrationState == .register && hasFlushedPendingWrites()) ||
            (newWriteRegistrationState == .unregister && !hasFlushedPendingWrites()),
            "illegal flushNow decision: \(newWriteRegistrationState) and \(hasFlushedPendingWrites())")
        return newWriteRegistrationState
    }

    public final func setOption<Option: ChannelOption>(_ option: Option, value: Option.Value) -> EventLoopFuture<Void> {
        if eventLoop.inEventLoop {
            let promise = eventLoop.makePromise(of: Void.self)
            executeAndComplete(promise) { try self.setOption0(option, value: value) }
            return promise.futureResult
        } else {
            return eventLoop.submit { try self.setOption0(option, value: value) }
        }
    }

    func setOption0<Option: ChannelOption>(_ option: Option, value: Option.Value) throws {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            throw ChannelError.ioOnClosedChannel
        }

        switch option {
        case let option as ChannelOptions.Types.SocketOption:
            try setSocketOption0(level: option.optionLevel, name: option.optionName, value: value)
        case _ as ChannelOptions.Types.AllocatorOption:
            bufferAllocator = value as! ByteBufferAllocator
        case _ as ChannelOptions.Types.RecvAllocatorOption:
            recvAllocator = value as! RecvByteBufferAllocator
        case _ as ChannelOptions.Types.AutoReadOption:
            let auto = value as! Bool
            let old = autoRead
            autoRead = auto

            // We only want to call read0() or pauseRead0() if we already registered to the EventLoop if not this will be automatically done
            // once register0 is called. Beside this we also only need to do it when the value actually change.
            if lifecycleManager.isPreRegistered, old != auto {
                if auto {
                    read0()
                } else {
                    pauseRead0()
                }
            }
        case _ as ChannelOptions.Types.MaxMessagesPerReadOption:
            maxMessagesPerRead = value as! UInt
        default:
            fatalError("option \(option) not supported")
        }
    }

    public func getOption<Option: ChannelOption>(_ option: Option) -> EventLoopFuture<Option.Value> {
        if eventLoop.inEventLoop {
            do {
                return eventLoop.makeSucceededFuture(try getOption0(option))
            } catch {
                return eventLoop.makeFailedFuture(error)
            }
        } else {
            return eventLoop.submit { try self.getOption0(option) }
        }
    }

    func getOption0<Option: ChannelOption>(_ option: Option) throws -> Option.Value {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            throw ChannelError.ioOnClosedChannel
        }

        switch option {
        case let option as ChannelOptions.Types.SocketOption:
            return try getSocketOption0(level: option.optionLevel, name: option.optionName)
        case _ as ChannelOptions.Types.AllocatorOption:
            return bufferAllocator as! Option.Value
        case _ as ChannelOptions.Types.RecvAllocatorOption:
            return recvAllocator as! Option.Value
        case _ as ChannelOptions.Types.AutoReadOption:
            return autoRead as! Option.Value
        case _ as ChannelOptions.Types.MaxMessagesPerReadOption:
            return maxMessagesPerRead as! Option.Value
        default:
            fatalError("option \(option) not supported")
        }
    }

    /// Triggers a `ChannelPipeline.read()` if `autoRead` is enabled.`
    ///
    /// - returns: `true` if `readPending` is `true`, `false` otherwise.
    @discardableResult func readIfNeeded0() -> Bool {
        eventLoop.assertInEventLoop()
        if !lifecycleManager.isActive {
            return false
        }

        if !readPending, autoRead {
            pipeline.read0()
        }
        return readPending
    }

    // Methods invoked from the HeadHandler of the ChannelPipeline
    public func bind0(to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            promise?.fail(ChannelError.ioOnClosedChannel)
            return
        }

        executeAndComplete(promise) {
            try socket.bind(to: address)
            self.updateCachedAddressesFromSocket(updateRemote: false)
        }
    }

    public final func write0(_ data: NIOAny, promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            // Channel was already closed, fail the promise and not even queue it.
            promise?.fail(ChannelError.ioOnClosedChannel)
            return
        }

        guard lifecycleManager.isActive else {
            promise?.fail(ChannelError.inappropriateOperationForState)
            return
        }

        bufferPendingWrite(data: data, promise: promise)
    }

    private func registerForWritable() {
        eventLoop.assertInEventLoop()

        guard !interestedEvent.contains(.write) else {
            // nothing to do if we were previously interested in write
            return
        }
        safeReregister(interested: interestedEvent.union(.write))
    }

    func unregisterForWritable() {
        eventLoop.assertInEventLoop()

        guard interestedEvent.contains(.write) else {
            // nothing to do if we were not previously interested in write
            return
        }
        safeReregister(interested: interestedEvent.subtracting(.write))
    }

    public final func flush0() {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            return
        }

        markFlushPoint()

        guard lifecycleManager.isActive else {
            return
        }

        if !isWritePending(), flushNow() == .register {
            assert(lifecycleManager.isPreRegistered)
            registerForWritable()
        }
    }

    public func read0() {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            return
        }
        readPending = true

        if lifecycleManager.isPreRegistered {
            registerForReadable()
        }
    }

    private final func pauseRead0() {
        eventLoop.assertInEventLoop()

        if lifecycleManager.isPreRegistered {
            unregisterForReadable()
        }
    }

    private final func registerForReadable() {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isRegisteredFully)

        guard !lifecycleManager.hasSeenEOFNotification else {
            // we have seen an EOF notification before so there's no point in registering for reads
            return
        }

        guard !interestedEvent.contains(.read) else {
            return
        }

        safeReregister(interested: interestedEvent.union(.read))
    }

    private final func registerForReadEOF() {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isRegisteredFully)

        guard !lifecycleManager.hasSeenEOFNotification else {
            // we have seen an EOF notification before so there's no point in registering for reads
            return
        }

        guard !interestedEvent.contains(.readEOF) else {
            return
        }

        safeReregister(interested: interestedEvent.union(.readEOF))
    }

    internal final func unregisterForReadable() {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isRegisteredFully)

        guard interestedEvent.contains(.read) else {
            return
        }

        safeReregister(interested: interestedEvent.subtracting(.read))
    }

    /// Closes the this `BaseChannelChannel` and fulfills `promise` with the result of the _close_ operation.
    /// So unless either the deregistration or the close itself fails, `promise` will be succeeded regardless of
    /// `error`. `error` is used to fail outstanding writes (if any) and the `connectPromise` if set.
    ///
    /// - parameters:
    ///    - error: The error to fail the outstanding (if any) writes/connect with.
    ///    - mode: The close mode, must be `.all` for `BaseSocketChannel`
    ///    - promise: The promise that gets notified about the result of the deregistration/close operations.
    public func close0(error: Error, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            promise?.fail(ChannelError.alreadyClosed)
            return
        }

        guard mode == .all else {
            promise?.fail(ChannelError.operationUnsupported)
            return
        }

        // === BEGIN: No user callouts ===

        // this is to register all error callouts as all the callouts must happen after we transition out state
        var errorCallouts: [(ChannelPipeline) -> Void] = []

        interestedEvent = .reset
        do {
            try selectableEventLoop.deregister(channel: self)
        } catch let err {
            errorCallouts.append { pipeline in
                pipeline.fireErrorCaught0(error: err)
            }
        }

        let p: EventLoopPromise<Void>?
        do {
            try socket.close()
            p = promise
        } catch {
            errorCallouts.append { (_: ChannelPipeline) in
                promise?.fail(error)
                // Set p to nil as we want to ensure we pass nil to becomeInactive0(...) so we not try to notify the promise again.
            }
            p = nil
        }

        // Transition our internal state.
        let callouts = lifecycleManager.close()

        // === END: No user callouts (now that our state is reconciled, we can call out to user code.) ===

        // this must be the first to call out as it transitions the PendingWritesManager into the closed state
        // and we assert elsewhere that the PendingWritesManager has the same idea of 'open' as we have in here.
        cancelWritesOnClose(error: error)

        // this should be a no-op as we shouldn't have any
        errorCallouts.forEach {
            $0(self.pipeline)
        }

        if let connectPromise = pendingConnect {
            pendingConnect = nil
            connectPromise.fail(error)
        }

        callouts(p, pipeline)

        eventLoop.execute {
            // ensure this is executed in a delayed fashion as the users code may still traverse the pipeline
            self.pipeline.removeHandlers()

            self.closePromise.succeed(())

            // Now reset the addresses as we notified all handlers / futures.
            self.unsetCachedAddressesFromSocket()
        }
    }

    public final func register0(promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            promise?.fail(ChannelError.ioOnClosedChannel)
            return
        }

        guard !lifecycleManager.isPreRegistered else {
            promise?.fail(ChannelError.inappropriateOperationForState)
            return
        }

        guard selectableEventLoop.isOpen else {
            let error = EventLoopError.shutdown
            pipeline.fireErrorCaught0(error: error)
            // `close0`'s error is about the result of the `close` operation, ...
            close0(error: error, mode: .all, promise: nil)
            // ... therefore we need to fail the registration `promise` separately.
            promise?.fail(error)
            return
        }

        // we can't fully register yet as epoll would give us EPOLLHUP if bind/connect wasn't called yet.
        lifecycleManager.beginRegistration()(promise, pipeline)
    }

    public final func registerAlreadyConfigured0(promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()
        assert(isOpen)
        assert(!lifecycleManager.isActive)
        let registerPromise = eventLoop.makePromise(of: Void.self)
        register0(promise: registerPromise)
        registerPromise.futureResult.whenFailure { (_: Error) in
            self.close(promise: nil)
        }
        registerPromise.futureResult.cascadeFailure(to: promise)

        if lifecycleManager.isPreRegistered {
            // we expect kqueue/epoll registration to always succeed which is basically true, except for errors that
            // should be fatal (EBADF, EFAULT, ESRCH, ENOMEM) and a two 'table full' (EMFILE, ENFILE) error kinds which
            // we don't handle yet but might do in the future (#469).
            try! becomeFullyRegistered0()
            if lifecycleManager.isRegisteredFully {
                becomeActive0(promise: promise)
            }
        }
    }

    public final func triggerUserOutboundEvent0(_: Any, promise: EventLoopPromise<Void>?) {
        promise?.fail(ChannelError.operationUnsupported)
    }

    // Methods invoked from the EventLoop itself
    public final func writable() {
        eventLoop.assertInEventLoop()
        assert(isOpen)

        finishConnect() // If we were connecting, that has finished.

        switch flushNow() {
        case .unregister:
            // Everything was written or connect was complete, let's unregister from writable.
            finishWritable()
        case .register:
            assert(!isOpen || interestedEvent.contains(.write))
            () // nothing to do because given that we just received `writable`, we're still registered for writable.
        }
    }

    private func finishConnect() {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isPreRegistered)

        if let connectPromise = pendingConnect {
            assert(!lifecycleManager.isActive)

            do {
                try finishConnectSocket()
            } catch {
                assert(!lifecycleManager.isActive)
                // close0 fails the connectPromise itself so no need to do it here
                close0(error: error, mode: .all, promise: nil)
                return
            }
            // now this has succeeded, becomeActive0 will actually fulfill this.
            pendingConnect = nil
            // We already know what the local address is.
            updateCachedAddressesFromSocket(updateLocal: false, updateRemote: true)
            becomeActive0(promise: connectPromise)
        } else {
            assert(lifecycleManager.isActive)
        }
    }

    private func finishWritable() {
        eventLoop.assertInEventLoop()

        if isOpen {
            assert(lifecycleManager.isPreRegistered)
            assert(!hasFlushedPendingWrites())
            unregisterForWritable()
        }
    }

    func writeEOF() {
        fatalError("\(self) received writeEOF which is unexpected")
    }

    func readEOF() {
        assert(!lifecycleManager.hasSeenEOFNotification)
        lifecycleManager.hasSeenEOFNotification = true

        // we can't be not active but still registered here; this would mean that we got a notification about a
        // channel before we're ready to receive them.
        assert(lifecycleManager.isRegisteredFully,
               "illegal state: \(self): active: \(lifecycleManager.isActive), registered: \(lifecycleManager.isRegisteredFully)")

        readEOF0()

        assert(!interestedEvent.contains(.read))
        assert(!interestedEvent.contains(.readEOF))
    }

    final func readEOF0() {
        if lifecycleManager.isRegisteredFully {
            // we're unregistering from `readEOF` here as we want this to be one-shot. We're then synchronously
            // reading all input until the EOF that we're guaranteed to see. After that `readEOF` becomes uninteresting
            // and would anyway fire constantly.
            safeReregister(interested: interestedEvent.subtracting(.readEOF))

            loop: while lifecycleManager.isActive {
                switch readable0() {
                case .eof:
                    // on EOF we stop the loop and we're done with our processing for `readEOF`.
                    // we could both be registered & active (if our channel supports half-closure) or unregistered & inactive (if it doesn't).
                    break loop
                case .error:
                    // we should be unregistered and inactive now (as `readable0` would've called close).
                    assert(!lifecycleManager.isActive)
                    assert(!lifecycleManager.isPreRegistered)
                    break loop
                case .normal(.none):
                    preconditionFailure("got .readEOF and read returned not reading any bytes, nor EOF.")
                case .normal(.some):
                    // normal, note that there is no guarantee we're still active (as the user might have closed in callout)
                    continue loop
                }
            }
        }
    }

    // this _needs_ to synchronously cause the fd to be unregistered because we cannot unregister from `reset`. In
    // other words: Failing to unregister the whole selector will cause NIO to spin at 100% CPU constantly delivering
    // the `reset` event.
    final func reset() {
        readEOF0()

        if socket.isOpen {
            assert(lifecycleManager.isPreRegistered)
            let error: IOError
            // if the socket is still registered (and therefore open), let's try to get the actual socket error from the socket
            do {
                let result: Int32 = try socket.getOption(level: .socket, name: .so_error)
                if result != 0 {
                    // we have a socket error, let's forward
                    // this path will be executed on Linux (EPOLLERR) & Darwin (ev.fflags != 0)
                    error = IOError(errnoCode: result, reason: "connection reset (error set)")
                } else {
                    // we don't have a socket error, this must be connection reset without an error then
                    // this path should only be executed on Linux (EPOLLHUP, no EPOLLERR)
                    #if os(Linux)
                        let message: String = "connection reset (no error set)"
                    #else
                        let message: String = "BUG IN SwiftNIO (possibly #572), please report! Connection reset (no error set)."
                    #endif
                    error = IOError(errnoCode: ECONNRESET, reason: message)
                }
                close0(error: error, mode: .all, promise: nil)
            } catch {
                close0(error: error, mode: .all, promise: nil)
            }
        }
        assert(!lifecycleManager.isPreRegistered)
    }

    public final func readable() {
        assert(!lifecycleManager.hasSeenEOFNotification,
               "got a read notification after having already seen .readEOF")
        readable0()
    }

    @discardableResult
    private final func readable0() -> ReadStreamState {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isActive)

        defer {
            if self.isOpen, !self.readPending {
                unregisterForReadable()
            }
        }

        let readResult: ReadResult
        do {
            readResult = try readFromSocket()
        } catch let err {
            let readStreamState: ReadStreamState
            // ChannelError.eof is not something we want to fire through the pipeline as it just means the remote
            // peer closed / shutdown the connection.
            if let channelErr = err as? ChannelError, channelErr == ChannelError.eof {
                readStreamState = .eof
                // Directly call getOption0 as we are already on the EventLoop and so not need to create an extra future.

                // getOption0 can only fail if the channel is not active anymore but we assert further up that it is. If
                // that's not the case this is a precondition failure and we would like to know.
                if self.lifecycleManager.isActive, try! self.getOption0(ChannelOptions.allowRemoteHalfClosure) {
                    // If we want to allow half closure we will just mark the input side of the Channel
                    // as closed.
                    assert(self.lifecycleManager.isActive)
                    self.pipeline.fireChannelReadComplete0()
                    if self.shouldCloseOnReadError(err) {
                        self.close0(error: err, mode: .input, promise: nil)
                    }
                    self.readPending = false
                    return .eof
                }
            } else {
                readStreamState = .error
                self.pipeline.fireErrorCaught0(error: err)
            }

            // Call before triggering the close of the Channel.
            if readStreamState != .error, self.lifecycleManager.isActive {
                self.pipeline.fireChannelReadComplete0()
            }

            if self.shouldCloseOnReadError(err) {
                self.close0(error: err, mode: .all, promise: nil)
            }

            return readStreamState
        }
        // This assert needs to be disabled for io_uring, as the io_uring backend does not have the implicit synchronisation between
        // modifications to the poll mask and the actual returned events on the completion queue that kqueue and epoll has.
        // For kqueue and epoll, there is an implicit synchronisation point such that after a modification of the poll mask has been
        // issued, the next call to reap events will be sure to not include events which does not match the new poll mask.
        // Specifically for this assert, it means that we will be guaranteed to never receive a POLLIN notification unless there are
        // bytes available to read.

        // For a fully asynchronous backend like io_uring, there are no such implicit synchronisation point, so after we have
        // submitted the asynchronous event to change the poll mask, we may still reap pending asynchronous replies for the old
        // poll mask, and thus receive a POLLIN even though we have modified the mask visavi the kernel.
        // Which would trigger the assert.

        // The only way to avoid that race, would be to use heavy handed synchronisation primitives like IOSQE_IO_DRAIN (basically
        // flushing all pending requests and wait for a fake event result to sync up) which would be awful for performance,
        // so better skip the assert() for io_uring instead.
        #if !SWIFTNIO_USE_IO_URING
            assert(readResult == .some)
        #endif
        if lifecycleManager.isActive {
            pipeline.fireChannelReadComplete0()
        }
        readIfNeeded0()
        return .normal(readResult)
    }

    /// Returns `true` if the `Channel` should be closed as result of the given `Error` which happened during `readFromSocket`.
    ///
    /// - parameters:
    ///     - err: The `Error` which was thrown by `readFromSocket`.
    /// - returns: `true` if the `Channel` should be closed, `false` otherwise.
    func shouldCloseOnReadError(_: Error) -> Bool {
        true
    }

    internal final func updateCachedAddressesFromSocket(updateLocal: Bool = true, updateRemote: Bool = true) {
        eventLoop.assertInEventLoop()
        assert(updateLocal || updateRemote)
        let cached = addressesCached
        let local = updateLocal ? try? localAddress0() : cached.local
        let remote = updateRemote ? try? remoteAddress0() : cached.remote
        addressesCached = AddressCache(local: local, remote: remote)
    }

    internal final func unsetCachedAddressesFromSocket() {
        eventLoop.assertInEventLoop()
        addressesCached = AddressCache(local: nil, remote: nil)
    }

    public final func connect0(to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()

        guard isOpen else {
            promise?.fail(ChannelError.ioOnClosedChannel)
            return
        }

        guard pendingConnect == nil else {
            promise?.fail(ChannelError.connectPending)
            return
        }

        guard lifecycleManager.isPreRegistered else {
            promise?.fail(ChannelError.inappropriateOperationForState)
            return
        }

        do {
            if try !connectSocket(to: address) {
                // We aren't connected, we'll get the remote address later.
                updateCachedAddressesFromSocket(updateLocal: true, updateRemote: false)
                if promise != nil {
                    pendingConnect = promise
                } else {
                    pendingConnect = eventLoop.makePromise()
                }
                try becomeFullyRegistered0()
                registerForWritable()
            } else {
                updateCachedAddressesFromSocket()
                becomeActive0(promise: promise)
            }
        } catch {
            assert(lifecycleManager.isPreRegistered)
            // We would like to have this assertion here, but we want to be able to go through this
            // code path in cases where connect() is being called on channels that are already active.
            // assert(!self.lifecycleManager.isActive)
            // We're going to set the promise as the pending connect promise, and let close0 fail it for us.
            pendingConnect = promise
            close0(error: error, mode: .all, promise: nil)
        }
    }

    public func channelRead0(_: NIOAny) {
        // Do nothing by default
        // note: we can't assert that we're active here as TailChannelHandler will call this on channelRead
    }

    public func errorCaught0(error _: Error) {
        // Do nothing
    }

    private func isWritePending() -> Bool {
        interestedEvent.contains(.write)
    }

    private final func safeReregister(interested: SelectorEventSet) {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isRegisteredFully)

        guard isOpen else {
            assert(interestedEvent == .reset, "interestedEvent=\(interestedEvent) even though we're closed")
            return
        }
        if interested == interestedEvent {
            // we don't need to update and so cause a syscall if we already are registered with the correct event
            return
        }
        interestedEvent = interested
        do {
            try selectableEventLoop.reregister(channel: self)
        } catch let err {
            self.pipeline.fireErrorCaught0(error: err)
            self.close0(error: err, mode: .all, promise: nil)
        }
    }

    private func safeRegister(interested: SelectorEventSet) throws {
        eventLoop.assertInEventLoop()
        assert(!lifecycleManager.isRegisteredFully)

        guard isOpen else {
            throw ChannelError.ioOnClosedChannel
        }

        interestedEvent = interested
        do {
            try selectableEventLoop.register(channel: self)
        } catch {
            pipeline.fireErrorCaught0(error: error)
            close0(error: error, mode: .all, promise: nil)
            throw error
        }
    }

    final func becomeFullyRegistered0() throws {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isPreRegistered)
        assert(!lifecycleManager.isRegisteredFully)

        // The initial set of interested events must not contain `.readEOF` because when connect doesn't return
        // synchronously, kevent might send us a `readEOF` because the `writable` event that marks the connect as completed.
        // See SocketChannelTest.testServerClosesTheConnectionImmediately for a regression test.
        try safeRegister(interested: [.reset])
        lifecycleManager.finishRegistration()(nil, pipeline)
    }

    final func becomeActive0(promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()
        assert(lifecycleManager.isPreRegistered)
        if !lifecycleManager.isRegisteredFully {
            do {
                try becomeFullyRegistered0()
                assert(lifecycleManager.isRegisteredFully)
            } catch {
                close0(error: error, mode: .all, promise: promise)
                return
            }
        }
        lifecycleManager.activate()(promise, pipeline)
        guard lifecycleManager.isOpen else {
            // in the user callout for `channelActive` the channel got closed.
            return
        }
        registerForReadEOF()
        readIfNeeded0()
    }

    func register(selector _: Selector<NIORegistration>, interested _: SelectorEventSet) throws {
        fatalError("must override")
    }

    func deregister(selector _: Selector<NIORegistration>, mode _: CloseMode) throws {
        fatalError("must override")
    }

    func reregister(selector _: Selector<NIORegistration>, interested _: SelectorEventSet) throws {
        fatalError("must override")
    }
}

extension BaseSocketChannel {
    public struct SynchronousOptions: NIOSynchronousChannelOptions {
        @usableFromInline // should be private
        internal let _channel: BaseSocketChannel<SocketType>

        @inlinable // should be fileprivate
        internal init(_channel channel: BaseSocketChannel<SocketType>) {
            _channel = channel
        }

        @inlinable
        public func setOption<Option: ChannelOption>(_ option: Option, value: Option.Value) throws {
            try _channel.setOption0(option, value: value)
        }

        @inlinable
        public func getOption<Option: ChannelOption>(_ option: Option) throws -> Option.Value {
            try _channel.getOption0(option)
        }
    }

    public final var syncOptions: NIOSynchronousChannelOptions? {
        SynchronousOptions(_channel: self)
    }
}
