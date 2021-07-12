//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// NIOConcurrencyHelpersTests+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension NIOConcurrencyHelpersTests {

   @available(*, deprecated, message: "not actually deprecated. Just deprecated to allow deprecated tests (which test deprecated functionality) without warnings")
   static var allTests : [(String, (NIOConcurrencyHelpersTests) -> () throws -> Void)] {
      return [
                ("testLargeContendedAtomicSum", testLargeContendedAtomicSum),
                ("testCompareAndExchangeBool", testCompareAndExchangeBool),
                ("testAllOperationsBool", testAllOperationsBool),
                ("testCompareAndExchangeUInts", testCompareAndExchangeUInts),
                ("testCompareAndExchangeInts", testCompareAndExchangeInts),
                ("testAddSub", testAddSub),
                ("testExchange", testExchange),
                ("testLoadStore", testLoadStore),
                ("testLargeContendedNIOAtomicSum", testLargeContendedNIOAtomicSum),
                ("testCompareAndExchangeBoolNIOAtomic", testCompareAndExchangeBoolNIOAtomic),
                ("testAllOperationsBoolNIOAtomic", testAllOperationsBoolNIOAtomic),
                ("testCompareAndExchangeUIntsNIOAtomic", testCompareAndExchangeUIntsNIOAtomic),
                ("testCompareAndExchangeIntsNIOAtomic", testCompareAndExchangeIntsNIOAtomic),
                ("testAddSubNIOAtomic", testAddSubNIOAtomic),
                ("testExchangeNIOAtomic", testExchangeNIOAtomic),
                ("testLoadStoreNIOAtomic", testLoadStoreNIOAtomic),
                ("testLockMutualExclusion", testLockMutualExclusion),
                ("testWithLockMutualExclusion", testWithLockMutualExclusion),
                ("testConditionLockMutualExclusion", testConditionLockMutualExclusion),
                ("testConditionLock", testConditionLock),
                ("testConditionLockWithDifferentConditions", testConditionLockWithDifferentConditions),
                ("testAtomicBoxDoesNotTriviallyLeak", testAtomicBoxDoesNotTriviallyLeak),
                ("testAtomicBoxCompareAndExchangeWorksIfEqual", testAtomicBoxCompareAndExchangeWorksIfEqual),
                ("testAtomicBoxCompareAndExchangeWorksIfNotEqual", testAtomicBoxCompareAndExchangeWorksIfNotEqual),
                ("testAtomicBoxStoreWorks", testAtomicBoxStoreWorks),
                ("testAtomicBoxCompareAndExchangeOntoItselfWorks", testAtomicBoxCompareAndExchangeOntoItselfWorks),
                ("testAtomicLoadMassLoadAndStore", testAtomicLoadMassLoadAndStore),
                ("testAtomicBoxCompareAndExchangeOntoItself", testAtomicBoxCompareAndExchangeOntoItself),
                ("testLoadAndExchangeHammering", testLoadAndExchangeHammering),
                ("testLoadAndStoreHammering", testLoadAndStoreHammering),
                ("testLoadAndCASHammering", testLoadAndCASHammering),
                ("testMultipleLoadsRacingWhilstStoresAreGoingOn", testMultipleLoadsRacingWhilstStoresAreGoingOn),
           ]
   }
}

