//
//  Components.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation

@MainActor
public protocol RossiActivityMachine<Activity> {
    associatedtype Activity: Sendable
    
    func run(activity: Activity) async
    func notifyFastForwarding()
    func reset()
}

@MainActor
public protocol RossiSideEffectMachine<SideEffect> {
    associatedtype SideEffect: Sendable
    
    func run(sideEffect: SideEffect) async
    func notifyCancellation()
    func reset()
}

@MainActor
public protocol RossiComputationMachine<Computation> {
    associatedtype Computation: Sendable
    
    func run(computation: Computation) async -> Any?
    func notifyCancellation()
    func reset()
}

@MainActor
public protocol RossiQuestionBox<Question> {
    associatedtype Question: Sendable
    
    func ask(question: Question)
    func show()
    func hide()
}
