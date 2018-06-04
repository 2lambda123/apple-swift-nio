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

/// AppendableCollection is a protocol partway between Collection and
/// RangeReplaceableCollection. It defines the append method that is present
/// on RangeReplaceableCollection, which makes all RangeReplaceableCollections
/// trivially able to implement this protocol.
public protocol AppendableCollection: Collection {
    mutating func append(_ newElement: Self.Iterator.Element)
}

/// An automatically expanding ring buffer implementation backed by a `ContiguousArray`. Even though this implementation
/// will automatically expand if more elements than `initialRingCapacity` are stored, it's advantageous to prevent
/// expansions from happening frequently. Expansions will always force an allocation and a copy to happen.
public struct CircularBuffer<E>: CustomStringConvertible, AppendableCollection, BidirectionalCollection, RandomAccessCollection, RangeReplaceableCollection
{
    // this typealias is so complicated because of SR-6963, when that's fixed we can drop the generic parameters and the where clause
    #if swift(>=4.2)
    public typealias RangeType<Bound> = Range<Bound> where Bound: Strideable, Bound.Stride: SignedInteger
    #else
    public typealias RangeType<Bound> = CountableRange<Bound> where Bound: Strideable, Bound.Stride: SignedInteger
    #endif
    private var buffer: ContiguousArray<E?>

    /// The index into the buffer of the first item
    private(set) /* private but tests */ internal var headIdx = 0

    /// The index into the buffer of the next free slot
    private(set) /* private but tests */ internal var tailIdx = 0

    /// Bitmask used for calculating the tailIdx / headIdx based on the fact that the underlying storage
    /// has always a size of power of two.
    private var mask: Int {
        return self.buffer.count - 1
    }

    /// Allocates a buffer that can hold up to `initialRingCapacity` elements and initialise an empty ring backed by
    /// the buffer. When the ring grows to more than `initialRingCapacity` elements the buffer will be expanded.
    public init(initialRingCapacity: Int) {
        let capacity = Int(UInt32(initialRingCapacity).nextPowerOf2())
        self.buffer = ContiguousArray<E?>(repeating: nil, count: capacity)
        assert(self.buffer.count == capacity)
    }

    /// Allocates an empty buffer.
    public init() {
        self.buffer = ContiguousArray<E?>()
    }

    /// Append an element to the end of the ring buffer.
    ///
    /// Amortized *O(1)*
    public mutating func append(_ value: E) {
        self.buffer[self.tailIdx] = value
        self.tailIdx = (self.tailIdx + 1) & self.mask

        if self.headIdx == self.tailIdx {
            // No more room left for another append so grow the buffer now.
            self.doubleCapacity()
        }
    }

    /// Prepend an element to the front of the ring buffer.
    ///
    /// Amortized *O(1)*
    public mutating func prepend(_ value: E) {
        let idx = (self.headIdx - 1) & mask
        self.buffer[idx] = value
        self.headIdx = idx

        if self.headIdx == self.tailIdx {
            // No more room left for another append so grow the buffer now.
            self.doubleCapacity()
        }
    }

    /// Replaces the specified subrange of elements with the given collection.
    ///
    /// - Parameter subrange:
    /// The subrange of the collection to replace. The bounds of the range must be valid indices of the collection.
    ///
    /// - Parameter newElements:
    /// The new elements to add to the collection.
    ///
    /// *O(n)* where _n_ is the length of the new elements collection if the subrange equals to _n_
    ///
    /// *O(m)* where _m_ is the combined length of the collection and _newElements_
    public mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C : Collection, E == C.Element {
        precondition(subrange.lowerBound >= self.startIndex && subrange.upperBound <= self.endIndex, "Subrange out of bounds")

        let lowerBound = bufferIndex(ofIndex: subrange.lowerBound)
        let upperBound = bufferIndex(ofIndex: subrange.upperBound == self.endIndex ? subrange.upperBound - 1 : subrange.upperBound)

        if subrange.count == newElements.count {
            for (index, element) in zip(stride(from: subrange.lowerBound, to: subrange.upperBound, by: 1), newElements) {
                self.buffer[self.bufferIndex(ofIndex: index)] = element
            }
        } else if subrange.count == self.count && newElements.isEmpty {
            self.removeSubrange(subrange)
        } else {
            var newBuffer: ContiguousArray<E?> = []
            let capacityDelta = (newElements.count - subrange.count)
            let newCapacity = Int(UInt32(self.buffer.count + capacityDelta).nextPowerOf2())
            newBuffer.reserveCapacity(newCapacity)
            var index = self.headIdx
            while index != self.tailIdx {
                if index == lowerBound {
                    for element in newElements {
                        newBuffer.append(element)
                    }
                    while index < upperBound {
                        index = self.bufferIndex(after: index)
                    }
                } else {
                    newBuffer.append(self.buffer[index])
                    index = self.bufferIndex(after: index)
                }
            }

            self.tailIdx = newBuffer.count
            let repetitionCount = self.buffer.count - newBuffer.count
            if repetitionCount > 0 {
                newBuffer.append(contentsOf: repeatElement(nil, count: repetitionCount))
            }
            self.headIdx = 0
            self.buffer = newBuffer
        }
    }

    public mutating func removeSubrange(_ bounds: Range<Int>) {
        if bounds.count == 1 {
            _ = remove(at: bounds.lowerBound)
        } else if bounds.count == self.count {
            self = .init(initialRingCapacity: self.buffer.count)
        } else {
            replaceSubrange(bounds, with: [])
        }
    }

    public mutating func removeLast(_ n: Int) {
        let end = self.tailIdx
        self.tailIdx = (self.tailIdx - n) & self.mask
        for index in end - n ..< end {
            self.buffer[index] = nil
        }
    }

    /// Double the capacity of the buffer and adjust the headIdx and tailIdx.
    private mutating func doubleCapacity() {
        var newBacking: ContiguousArray<E?> = []
        let newCapacity = self.buffer.count << 1 // Double the storage.
        precondition(newCapacity > 0, "Can't double capacity of \(self.buffer.count)")
        assert(newCapacity % 2 == 0)

        newBacking.reserveCapacity(newCapacity)
        newBacking.append(contentsOf: self.buffer[self.headIdx..<self.buffer.count])
        if self.headIdx > 0 {
            newBacking.append(contentsOf: self.buffer[0..<self.headIdx])
        }
        newBacking.append(contentsOf: repeatElement(nil, count: newCapacity - newBacking.count))
        self.tailIdx = self.buffer.count
        self.headIdx = 0
        self.buffer = newBacking
    }

    /// Removes & returns the item at `position` from the buffer
    ///
    /// - Parameter position: The index of the item to be removed from the buffer.
    ///
    /// *O(1)* if the position is `headIdx` or `tailIdx`.
    /// otherwise
    /// *O(n)* where *n* is the number of elements between `position` and `tailIdx`.
    public mutating func remove(at position: Int) -> E {
        var bufferIndex = self.bufferIndex(ofIndex: position)
        let element = self.buffer[bufferIndex]!

        switch bufferIndex {
        case self.headIdx:
            self.headIdx = (self.headIdx + 1) & self.mask
            self.buffer[bufferIndex] = nil
        case self.tailIdx - 1:
            self.tailIdx = (self.tailIdx - 1) & self.mask
            self.buffer[bufferIndex] = nil
        default:
            var nextIndex = self.bufferIndex(after: bufferIndex)
            while nextIndex != self.tailIdx {
                self.buffer[bufferIndex] = self.buffer[nextIndex]
                bufferIndex = nextIndex
                nextIndex = self.bufferIndex(after: bufferIndex)
            }
            self.buffer[nextIndex] = nil
            self.tailIdx = (self.tailIdx - 1) & self.mask
        }

        return element
    }

    /// Return the first element of the ring.
    ///
    /// *O(1)*
    public var first: E? {
        if self.isEmpty {
            return nil
        } else {
            return self.buffer[self.headIdx]
        }
    }

    /// Return the last element of the ring.
    ///
    /// *O(1)*
    public var last: E? {
        if self.isEmpty {
            return nil
        } else {
            return self.buffer[(self.tailIdx - 1) & self.mask]
        }
    }

    private func bufferIndex(ofIndex index: Int) -> Int {
        precondition(index < self.count, "index out of range")
        return (self.headIdx + index) & self.mask
    }

    /// Returns the internal buffer next index after `index`.
    private func bufferIndex(after: Int) -> Int {
        let nextIndex = (after + 1) >= self.capacity ? 0 : (after + 1)
        return nextIndex
    }

    /// Returns the internal buffer index before `index`.
    private func bufferIndex(before: Int) -> Int {
        let previousIndex = (before - 1) < 0 ? self.tailIdx : (before - 1)
        return previousIndex
    }

    // MARK: Collection implementation
    /// Return element `index` of the ring.
    ///
    /// *O(1)*
    public subscript(index: Int) -> E {
        get {
            return self.buffer[self.bufferIndex(ofIndex: index)]!
        }
        set {
            self.buffer[self.bufferIndex(ofIndex: index)] = newValue
        }
    }

    /// Slice out a range of the ring.
    ///
    /// *O(1)*
    public subscript(bounds: Range<Int>) -> Slice<CircularBuffer<E>> {
        get {
            return Slice(base: self, bounds: bounds)
        }
    }

    /// Return all valid indices of the ring.
    public var indices: RangeType<Int> {
        return 0..<self.count
    }

    /// Returns whether the ring is empty.
    public var isEmpty: Bool {
        return self.headIdx == self.tailIdx
    }

    /// Returns the number of element in the ring.
    public var count: Int {
        return (self.tailIdx - self.headIdx) & self.mask
    }

    /// The total number of elements that the ring can contain without allocating new storage.
    public var capacity: Int {
        return self.buffer.count
    }

    /// Returns the index of the first element of the ring.
    public var startIndex: Int {
        return 0
    }

    /// Returns the ring's "past the end" position -- that is, the position one greater than the last valid subscript argument.
    public var endIndex: Int {
        return self.count
    }

    /// Returns the next index after `index`.
    public func index(after: Int) -> Int {
        let nextIndex = after + 1
    	precondition(nextIndex <= self.endIndex)
        return nextIndex
    }

    /// Returns the index before `index`.
    public func index(before: Int) -> Int {
        let previousIndex = before - 1
        precondition(previousIndex >= 0)
        return previousIndex
    }

    /// Removes all members from the circular buffer whist keeping the capacity.
    public mutating func removeAll(keepingCapacity: Bool = false) {
        self.headIdx = 0
        self.tailIdx = 0
        self.buffer = ContiguousArray<E?>(repeating: nil, count: keepingCapacity ? self.buffer.count : 1)
    }

    // MARK: CustomStringConvertible implementation
    /// Returns a human readable description of the ring.
    public var description: String {
        var desc = "[ "
        for el in self.buffer.enumerated() {
            if el.0 == self.headIdx {
                desc += "<"
            } else if el.0 == self.tailIdx {
                desc += ">"
            }
            desc += el.1.map { "\($0) " } ?? "_ "
        }
        desc += "]"
        desc += " (bufferCapacity: \(self.buffer.count), ringLength: \(self.count))"
        return desc
    }
}
