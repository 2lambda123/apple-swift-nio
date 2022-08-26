//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import XCTest

#if compiler(>=5.5.2) && canImport(_Concurrency)
private struct SomeError: Error, Hashable {}

private final class MockAsyncWriterDelegate: NIOAsyncWriterDelegate, @unchecked Sendable {
    typealias Element = String
    typealias Failure = SomeError

    var didYieldCallCount = 0
    var didYieldHandler: ((AnySequence<String>) -> Void)?
    func didYield<S: Sequence>(contentsOf sequence: S) where S.Element == String {
        self.didYieldCallCount += 1
        if let didYieldHandler = self.didYieldHandler {
            didYieldHandler(AnySequence(sequence))
        }
    }

    var didTerminateCallCount = 0
    var didTerminateHandler: ((NIOAsyncWriterCompletion<Failure>) -> Void)?
    func didTerminate(completion: NIOAsyncWriterCompletion<Failure>) {
        self.didTerminateCallCount += 1
        if let didTerminateHandler = self.didTerminateHandler {
            didTerminateHandler(completion)
        }
    }
}

final class NIOAsyncWriterTests: XCTestCase {
    private var writer: NIOAsyncWriter<String, SomeError, MockAsyncWriterDelegate>!
    private var sink: NIOAsyncWriter<String, SomeError, MockAsyncWriterDelegate>.Sink!
    private var delegate: MockAsyncWriterDelegate!

    override func setUp() {
        super.setUp()

        self.delegate = .init()
        let newWriter = NIOAsyncWriter.makeWriter(
            elementType: String.self,
            failureType: SomeError.self,
            isWritable: true,
            delegate: self.delegate
        )
        self.writer = newWriter.writer
        self.sink = newWriter.sink
    }

    override func tearDown() {
        self.delegate = nil
        self.writer = nil
        self.sink = nil

        super.tearDown()
    }

    func testMultipleConcurrentWrites() async throws {
        let task1 = Task { [writer] in
            for i in 0...9 {
                try await writer!.yield("message\(i)")
            }
        }
        let task2 = Task { [writer] in
            for i in 10...19 {
                try await writer!.yield("message\(i)")
            }
        }
        let task3 = Task { [writer] in
            for i in 20...29 {
                try await writer!.yield("message\(i)")
            }
        }

        try await task1.value
        try await task2.value
        try await task3.value

        XCTAssertEqual(self.delegate.didYieldCallCount, 30)
    }

    // MARK: - WriterDeinitialized

    func testWriterDeinitialized_whenInitial() async throws {
        self.writer = nil

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    func testWriterDeinitialized_whenStreaming() async throws {
        Task { [writer] in
            try await writer!.yield("message1")
        }

        try await Task.sleep(nanoseconds: 1_000_000)

        self.writer = nil

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    func testWriterDeinitialized_whenFinished() async throws {
        self.writer.finish(completion: .finished)

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)

        self.writer = nil

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    // MARK: - ToggleWritability

    func testToggleWritability_whenInitial() async throws {
        self.sink.toggleWritability()

        Task { [writer] in
            try await writer!.yield("message1")
        }

        // Sleep a bit so that the other Task suspends on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(self.delegate.didYieldCallCount, 0)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 0)
    }

    func testToggleWritability_whenStreaming_andBecomingUnwritable() async throws {
        try await self.writer.yield("message1")
        XCTAssertEqual(self.delegate.didYieldCallCount, 1)

        self.sink.toggleWritability()

        Task { [writer] in
            try await writer!.yield("message2")
        }

        // Sleep a bit so that the other Task suspends on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 0)
    }

    func testToggleWritability_whenStreaming_andBecomingWritable() async throws {
        self.sink.toggleWritability()

        Task { [writer] in
            try await writer!.yield("message2")
        }

        // Sleep a bit so that the other Task suspends on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        self.sink.toggleWritability()

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 0)
    }

    func testToggleWritability_whenFinished() async throws {
        self.writer.finish(completion: .finished)

        self.sink.toggleWritability()

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    // MARK: - Yield

    func testYield_whenInitial_andWritable() async throws {
        try await self.writer.yield("message1")

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
    }

    func testYield_whenInitial_andNotWritable() async throws {
        self.sink.toggleWritability()

        Task { [writer] in
            try await writer!.yield("message2")
        }

        // Sleep a bit so that the other Task suspends on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(self.delegate.didYieldCallCount, 0)
    }

    func testYield_whenStreaming_andWritable() async throws {
        try await self.writer.yield("message1")

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)

        try await self.writer.yield("message2")

        XCTAssertEqual(self.delegate.didYieldCallCount, 2)
    }

    func testYield_whenStreaming_andNotWritable() async throws {
        try await self.writer.yield("message1")

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)

        self.sink.toggleWritability()

        Task { [writer] in
            try await writer!.yield("message2")
        }

        // Sleep a bit so that the other Task suspends on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
    }

    func testYield_whenStreaming_andYieldCancelled() async throws {
        try await self.writer.yield("message1")

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)

        let task = Task { [writer] in
            // Sleeping here a bit to delay the call to yield
            // The idea is that we call yield once the Task is
            // already cancelled
            try? await Task.sleep(nanoseconds: 1_000_000)
            try await writer!.yield("message2")
        }

        task.cancel()

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
        await XCTAssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testYield_whenFinished() async throws {
        self.writer.finish(completion: .finished)

        await XCTAssertThrowsError(try await self.writer.yield("message1")) { error in
            XCTAssertEqual(error as? NIOAsyncWriterError, .alreadyFinished)
        }
        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    // MARK: - Cancel

    func testCancel_whenInitial() async throws {
        let task = Task { [writer] in
            // Sleeping here a bit to delay the call to yield
            // The idea is that we call yield once the Task is
            // already cancelled
            try? await Task.sleep(nanoseconds: 1_000_000)
            try await writer!.yield("message1")
        }

        task.cancel()

        XCTAssertEqual(self.delegate.didYieldCallCount, 0)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 0)
        await XCTAssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCancel_whenStreaming_andCancelBeforeYield() async throws {
        try await self.writer.yield("message1")

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)

        let task = Task { [writer] in
            // Sleeping here a bit to delay the call to yield
            // The idea is that we call yield once the Task is
            // already cancelled
            try? await Task.sleep(nanoseconds: 1_000_000)
            try await writer!.yield("message2")
        }

        task.cancel()

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 0)
        await XCTAssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCancel_whenStreaming_andCancelAfterSuspendedYield() async throws {
        try await self.writer.yield("message1")

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)

        self.sink.toggleWritability()

        let task = Task { [writer] in
            try await writer!.yield("message2")
        }

        // Sleeping here to give the task enough time to suspend on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        task.cancel()

        XCTAssertEqual(self.delegate.didYieldCallCount, 1)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 0)
        await XCTAssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCancel_whenFinished() async throws {
        self.writer.finish(completion: .finished)

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)

        let task = Task { [writer] in
            // Sleeping here a bit to delay the call to yield
            // The idea is that we call yield once the Task is
            // already cancelled
            try? await Task.sleep(nanoseconds: 1_000_000)
            try await writer!.yield("message1")
        }

        // Sleeping here to give the task enough time to suspend on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        task.cancel()

        XCTAssertEqual(self.delegate.didYieldCallCount, 0)
        await XCTAssertThrowsError(try await task.value) { error in
            XCTAssertEqual(error as? NIOAsyncWriterError, .alreadyFinished)
        }
    }

    // MARK: - Finish

    func testFinish_whenInitial() async throws {
        self.writer.finish(completion: .finished)

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    func testFinish_whenInitial_andFailure() async throws {
        self.writer.finish(completion: .failure(SomeError()))

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }

    func testFinish_whenStreaming() async throws {
        // We are setting up a suspended yield here to check that it gets resumed
        self.sink.toggleWritability()

        let task = Task { [writer] in
            try await writer!.yield("message1")
        }

        // Sleeping here to give the task enough time to suspend on the yield
        try await Task.sleep(nanoseconds: 1_000_000)

        self.writer.finish(completion: .finished)

        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
        await XCTAssertThrowsError(try await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testFinish_whenFinished() {
        // This tests just checks that finishing again is a no-op
        self.writer.finish(completion: .finished)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)

        self.writer.finish(completion: .finished)
        XCTAssertEqual(self.delegate.didTerminateCallCount, 1)
    }
}
#endif
