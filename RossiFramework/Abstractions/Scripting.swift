//
//  Scripting.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation

public protocol RossiCommandGeneratorProvider<CommandGenerator>: Actor {
    associatedtype CommandGenerator: RossiCommandGenerator
    
    func provide() async -> CommandGenerator?
}

public protocol RossiCommandGenerator<Activity, SideEffect, Computation, Question>: Actor {
    associatedtype Activity: Sendable
    associatedtype SideEffect: Sendable
    associatedtype Computation: Sendable
    associatedtype Question: Sendable
    
    func generate(payload: Any?) async -> RossiCommand<Activity, SideEffect, Computation, Question>?
    func reset() async
}

public enum RossiCommand<Activity, SideEffect, Computation, Question>: Sendable
where Activity: Sendable,
      SideEffect: Sendable,
      Computation: Sendable,
      Question: Sendable {
    case runActivity(activity: Activity)
    case runSideEffect(sideEffect: SideEffect)
    case runComputation(computation: Computation)
    case askQuestion(question: Question)
    case sleep(duration: TimeInterval)
    case halt
}
