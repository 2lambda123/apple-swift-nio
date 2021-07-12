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
//
// Codable+ByteBufferTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension CodableByteBufferTest {

   @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
   static var allTests : [(String, (CodableByteBufferTest) -> () throws -> Void)] {
      return [
                ("testSimpleDecode", testSimpleDecode),
                ("testSimpleEncodeIntoBuffer", testSimpleEncodeIntoBuffer),
                ("testSimpleEncodeToFreshByteBuffer", testSimpleEncodeToFreshByteBuffer),
                ("testGetJSONDecodableFromBufferWorks", testGetJSONDecodableFromBufferWorks),
                ("testGetJSONDecodableFromBufferFailsBecauseShort", testGetJSONDecodableFromBufferFailsBecauseShort),
                ("testReadJSONDecodableFromBufferWorks", testReadJSONDecodableFromBufferWorks),
                ("testReadJSONDecodableFromBufferFailsBecauseShort", testReadJSONDecodableFromBufferFailsBecauseShort),
                ("testReadWriteJSONDecodableWorks", testReadWriteJSONDecodableWorks),
                ("testGetSetJSONDecodableWorks", testGetSetJSONDecodableWorks),
                ("testFailingReadsDoNotChangeReaderIndex", testFailingReadsDoNotChangeReaderIndex),
                ("testCustomEncoderIsRespected", testCustomEncoderIsRespected),
                ("testCustomDecoderIsRespected", testCustomDecoderIsRespected),
                ("testCustomCodersAreRespectedWhenUsingReadWriteJSONDecodable", testCustomCodersAreRespectedWhenUsingReadWriteJSONDecodable),
           ]
   }
}

