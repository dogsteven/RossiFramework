//
//  Decoder.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import RossiFramework

public protocol RossiCommandDecoder {
    associatedtype Activity: Sendable
    associatedtype SideEffect: Sendable
    associatedtype Computation: Sendable
    associatedtype Question: Sendable
    
    func decode(message: String) -> RossiCommand<Activity, SideEffect, Computation, Question>?
}
