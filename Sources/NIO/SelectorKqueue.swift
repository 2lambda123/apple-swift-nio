//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

/// Represents the `kqueue` filters we might use:
///
///  - `except` corresponds to `EVFILT_EXCEPT`
///  - `read` corresponds to `EVFILT_READ`
///  - `write` corresponds to `EVFILT_WRITE`
private struct KQueueEventFilterSet: OptionSet, Equatable {
    typealias RawValue = UInt8

    let rawValue: RawValue

    static let _none = KQueueEventFilterSet([])
    // skipping `1 << 0` because kqueue doesn't have a direct match for `.reset` (`EPOLLHUP` for epoll)
    static let except = KQueueEventFilterSet(rawValue: 1 << 1)
    static let read = KQueueEventFilterSet(rawValue: 1 << 2)
    static let write = KQueueEventFilterSet(rawValue: 1 << 3)

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension KQueueEventFilterSet {
    /// Convert NIO's `SelectorEventSet` set to a `KQueueEventFilterSet`
    init(selectorEventSet: SelectorEventSet) {
        var kqueueFilterSet: KQueueEventFilterSet = .init(rawValue: 0)
        if selectorEventSet.contains(.read) {
            kqueueFilterSet.formUnion(.read)
        }

        if selectorEventSet.contains(.write) {
            kqueueFilterSet.formUnion(.write)
        }

        if isEarlyEOFDeliveryWorkingOnThisOS, selectorEventSet.contains(.readEOF) {
            kqueueFilterSet.formUnion(.except)
        }
        self = kqueueFilterSet
    }

    /// Calculate the kqueue filter changes that are necessary to transition from `previousKQueueFilterSet` to `self`.
    /// The `body` closure is then called with the changes necessary expressed as a number of `kevent`.
    ///
    /// - parameters:
    ///    - previousKQueueFilterSet: The previous filter set that is currently registered with kqueue.
    ///    - fileDescriptor: The file descriptor the `kevent`s should be generated to.
    ///    - body: The closure that will then apply the change set.
    func calculateKQueueFilterSetChanges(previousKQueueFilterSet: KQueueEventFilterSet,
                                         fileDescriptor: CInt,
                                         registrationID: SelectorRegistrationID,
                                         _ body: (UnsafeMutableBufferPointer<kevent>) throws -> Void) rethrows
    {
        // we only use three filters (EVFILT_READ, EVFILT_WRITE and EVFILT_EXCEPT) so the number of changes would be 3.
        var keventsHopefullyOnStack = (kevent(), kevent(), kevent())
        try withUnsafeMutableBytes(of: &keventsHopefullyOnStack) { rawPtr in
            assert(MemoryLayout<kevent>.size * 3 == rawPtr.count)
            let keventBuffer = rawPtr.baseAddress!.bindMemory(to: kevent.self, capacity: 3)

            let differences = previousKQueueFilterSet.symmetricDifference(self) // contains all the events that need a change (either need to be added or removed)

            func calculateKQueueChange(event: KQueueEventFilterSet) -> UInt16? {
                guard differences.contains(event) else {
                    return nil
                }
                return UInt16(self.contains(event) ? EV_ADD : EV_DELETE)
            }

            var index: Int = 0
            for (event, filter) in [(KQueueEventFilterSet.read, EVFILT_READ), (.write, EVFILT_WRITE), (.except, EVFILT_EXCEPT)] {
                if let flags = calculateKQueueChange(event: event) {
                    keventBuffer[index].setEvent(fileDescriptor: fileDescriptor, filter: filter, flags: flags, registrationID: registrationID)
                    index += 1
                }
            }
            try body(UnsafeMutableBufferPointer(start: keventBuffer, count: index))
        }
    }
}

extension SelectorRegistrationID {
    init(kqueueUData: UnsafeMutableRawPointer?) {
        self = .init(rawValue: UInt32(truncatingIfNeeded: UInt(bitPattern: kqueueUData)))
    }
}

/* this is deliberately not thread-safe, only the wakeup() function may be called unprotectedly */
extension Selector: _SelectorBackendProtocol {
    private static func toKQueueTimeSpec(strategy: SelectorStrategy) -> timespec? {
        switch strategy {
        case .block:
            return nil
        case .now:
            return timespec(tv_sec: 0, tv_nsec: 0)
        case let .blockUntilTimeout(nanoseconds):
            // A scheduledTask() specified with a zero or negative timeAmount, will be scheduled immediately
            // and therefore SHOULD NOT result in a kevent being created with a negative or zero timespec.
            precondition(nanoseconds.nanoseconds > 0, "\(nanoseconds) is invalid (0 < nanoseconds)")

            var ts = timespec(timeAmount: nanoseconds)
            // Check that the timespec tv_nsec field conforms to the definition in the C11 standard (ISO/IEC 9899:2011).
            assert((0 ..< 1_000_000_000).contains(ts.tv_nsec), "\(ts) is invalid (0 <= tv_nsec < 1_000_000_000)")

            // The maximum value in seconds supported by the Darwin-kernel interval timer (kern_time.c:itimerfix())
            // (note that - whilst unlikely - this value *could* change).
            let sysIntervalTimerMaxSec = 100_000_000

            // Clamp the timespec tv_sec value to the maximum supported by the Darwin-kernel.
            // Whilst this schedules the event far into the future (several years) it will still be triggered provided
            // the system stays up.
            ts.tv_sec = min(ts.tv_sec, sysIntervalTimerMaxSec)

            return ts
        }
    }

    /// Apply a kqueue changeset by calling the `kevent` function with the `kevent`s supplied in `keventBuffer`.
    private func kqueueApplyEventChangeSet(keventBuffer: UnsafeMutableBufferPointer<kevent>) throws {
        // WARNING: This is called on `self.myThread` OR with `self.externalSelectorFDLock` held.
        // So it MUST NOT touch anything on `self.` apart from constants and `self.selectorFD`.
        guard keventBuffer.count > 0 else {
            // nothing to do
            return
        }
        do {
            try KQueue.kevent(kq: selectorFD,
                              changelist: keventBuffer.baseAddress!,
                              nchanges: CInt(keventBuffer.count),
                              eventlist: nil,
                              nevents: 0,
                              timeout: nil)
        } catch let err as IOError {
            if err.errnoCode == EINTR {
                // See https://www.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2
                // When kevent() call fails with EINTR error, all changes in the changelist have been applied.
                return
            }
            throw err
        }
    }

    private func kqueueUpdateEventNotifications<S: Selectable>(selectable: S, interested: SelectorEventSet, oldInterested: SelectorEventSet?, registrationID: SelectorRegistrationID) throws {
        assert(myThread == NIOThread.current)
        let oldKQueueFilters = KQueueEventFilterSet(selectorEventSet: oldInterested ?? ._none)
        let newKQueueFilters = KQueueEventFilterSet(selectorEventSet: interested)
        assert(interested.contains(.reset))
        assert(oldInterested?.contains(.reset) ?? true)

        try selectable.withUnsafeHandle {
            try newKQueueFilters.calculateKQueueFilterSetChanges(previousKQueueFilterSet: oldKQueueFilters,
                                                                 fileDescriptor: $0,
                                                                 registrationID: registrationID,
                                                                 kqueueApplyEventChangeSet)
        }
    }

    func initialiseState0() throws {
        selectorFD = try KQueue.kqueue()
        lifecycleState = .open

        var event = kevent()
        event.ident = 0
        event.filter = Int16(EVFILT_USER)
        event.fflags = UInt32(NOTE_FFNOP)
        event.data = 0
        event.udata = nil
        event.flags = UInt16(EV_ADD | EV_ENABLE | EV_CLEAR)
        try withUnsafeMutablePointer(to: &event) { ptr in
            try kqueueApplyEventChangeSet(keventBuffer: UnsafeMutableBufferPointer(start: ptr, count: 1))
        }
    }

    func deinitAssertions0() {}

    func register0<S: Selectable>(selectable: S, fileDescriptor _: CInt, interested: SelectorEventSet, registrationID: SelectorRegistrationID) throws {
        try self.kqueueUpdateEventNotifications(selectable: selectable, interested: interested, oldInterested: nil, registrationID: registrationID)
    }

    func reregister0<S: Selectable>(selectable: S, fileDescriptor _: CInt, oldInterested: SelectorEventSet, newInterested: SelectorEventSet, registrationID: SelectorRegistrationID) throws {
        try self.kqueueUpdateEventNotifications(selectable: selectable, interested: newInterested, oldInterested: oldInterested, registrationID: registrationID)
    }

    func deregister0<S: Selectable>(selectable: S, fileDescriptor _: CInt, oldInterested: SelectorEventSet, registrationID: SelectorRegistrationID) throws {
        try self.kqueueUpdateEventNotifications(selectable: selectable, interested: .reset, oldInterested: oldInterested, registrationID: registrationID)
    }

    /// Apply the given `SelectorStrategy` and execute `body` once it's complete (which may produce `SelectorEvent`s to handle).
    ///
    /// - parameters:
    ///     - strategy: The `SelectorStrategy` to apply
    ///     - body: The function to execute for each `SelectorEvent` that was produced.
    func whenReady0(strategy: SelectorStrategy, onLoopBegin loopStart: () -> Void, _ body: (SelectorEvent<R>) throws -> Void) throws {
        assert(myThread == NIOThread.current)
        guard lifecycleState == .open else {
            throw IOError(errnoCode: EBADF, reason: "can't call whenReady for selector as it's \(lifecycleState).")
        }

        let timespec = Selector.toKQueueTimeSpec(strategy: strategy)
        let ready = try timespec.withUnsafeOptionalPointer { ts in
            Int(try KQueue.kevent(kq: self.selectorFD, changelist: nil, nchanges: 0, eventlist: events, nevents: Int32(eventsCapacity), timeout: ts))
        }

        loopStart()

        for i in 0 ..< ready {
            let ev = events[i]
            let filter = Int32(ev.filter)
            let eventRegistrationID = SelectorRegistrationID(kqueueUData: ev.udata)
            guard Int32(ev.flags) & EV_ERROR == 0 else {
                throw IOError(errnoCode: Int32(ev.data), reason: "kevent returned with EV_ERROR set: \(String(describing: ev))")
            }
            guard filter != EVFILT_USER, let registration = registrations[Int(ev.ident)] else {
                continue
            }
            guard eventRegistrationID == registration.registrationID else {
                continue
            }
            var selectorEvent: SelectorEventSet = ._none
            switch filter {
            case EVFILT_READ:
                selectorEvent.formUnion(.read)
                fallthrough // falling through here as `EVFILT_READ` also delivers `EV_EOF` (meaning `.readEOF`)
            case EVFILT_EXCEPT:
                if Int32(ev.flags) & EV_EOF != 0, registration.interested.contains(.readEOF) {
                    // we only add `.readEOF` if it happened and the user asked for it
                    selectorEvent.formUnion(.readEOF)
                }
            case EVFILT_WRITE:
                selectorEvent.formUnion(.write)
            default:
                // We only use EVFILT_USER, EVFILT_READ, EVFILT_EXCEPT and EVFILT_WRITE.
                fatalError("unexpected filter \(ev.filter)")
            }
            if ev.fflags != 0 {
                selectorEvent.formUnion(.reset)
            }
            // we can only verify the events for i == 0 as for i > 0 the user might have changed the registrations since then.
            assert(i != 0 || selectorEvent.isSubset(of: registration.interested), "selectorEvent: \(selectorEvent), registration: \(registration)")

            // in any case we only want what the user is currently registered for & what we got
            selectorEvent = selectorEvent.intersection(registration.interested)

            guard selectorEvent != ._none else {
                continue
            }
            try body(SelectorEvent(io: selectorEvent, registration: registration))
        }

        growEventArrayIfNeeded(ready: ready)
    }

    /// Close the `Selector`.
    ///
    /// After closing the `Selector` it's no longer possible to use it.
    func close0() throws {
        externalSelectorFDLock.withLock {
            // We try! all of the closes because close can only fail in the following ways:
            // - EINTR, which we eat in Posix.close
            // - EIO, which can only happen for on-disk files
            // - EBADF, which can't happen here because we would crash as EBADF is marked unacceptable
            // Therefore, we assert here that close will always succeed and if not, that's a NIO bug we need to know
            // about.
            // We limit close to only be for positive FD:s though, as subclasses (e.g. uring)
            // may already have closed some of these FD:s in their close function.

            try! Posix.close(descriptor: self.selectorFD)
            self.selectorFD = -1
        }
    }

    /* attention, this may (will!) be called from outside the event loop, ie. can't access mutable shared state (such as `self.open`) */
    func wakeup0() throws {
        assert(NIOThread.current != myThread)
        try externalSelectorFDLock.withLock {
            guard self.selectorFD >= 0 else {
                throw EventLoopError.shutdown
            }
            var event = kevent()
            event.ident = 0
            event.filter = Int16(EVFILT_USER)
            event.fflags = UInt32(NOTE_TRIGGER | NOTE_FFNOP)
            event.data = 0
            event.udata = nil
            event.flags = 0
            try withUnsafeMutablePointer(to: &event) { ptr in
                try self.kqueueApplyEventChangeSet(keventBuffer: UnsafeMutableBufferPointer(start: ptr, count: 1))
            }
        }
    }
}

extension kevent {
    /// Update a kevent for a given filter, file descriptor, and set of flags.
    mutating func setEvent(fileDescriptor fd: CInt, filter: CInt, flags: UInt16, registrationID: SelectorRegistrationID) {
        ident = UInt(fd)
        self.filter = Int16(filter)
        self.flags = flags
        udata = UnsafeMutableRawPointer(bitPattern: UInt(registrationID.rawValue))

        // On macOS, EVFILT_EXCEPT will fire whenever there is unread data in the socket receive
        // buffer. This is not a behaviour we want from EVFILT_EXCEPT: we only want it to tell us
        // about actually exceptional conditions. For this reason, when we set EVFILT_EXCEPT
        // we do it with NOTE_LOWAT set to Int.max, which will ensure that there is never enough data
        // in the send buffer to trigger EVFILT_EXCEPT. Thanks to the sensible design of kqueue,
        // this only affects our EXCEPT filter: EVFILT_READ behaves separately.
        if filter == EVFILT_EXCEPT {
            fflags = CUnsignedInt(NOTE_LOWAT)
            data = Int.max
        } else {
            fflags = 0
            data = 0
        }
    }
}

#endif
