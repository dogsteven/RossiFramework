//
//  SequenceStore.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

public struct SequenceStore {
    private var values: [Any?]
    
    public init() {
        self.values = []
    }
    
    public var last: Any? { values.last?.flatMap(\.self) }
    
    public var sequence: any Sequence<Any?> { values }
    
    public mutating func track(value: Any?) {
        values.append(value)
    }
    
    public mutating func clear() {
        values.removeAll(keepingCapacity: values.capacity < 256)
    }
}
