//
//  RossiFramework.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation

@MainActor
public final class RossiOrchestrator<ActivityMachine, SideEffectMachine, ComputationMachine, QuestionBox, CommandGeneratorProvider, SequenceStore>
where ActivityMachine: RossiActivityMachine,
      SideEffectMachine: RossiSideEffectMachine,
      ComputationMachine: RossiComputationMachine,
      QuestionBox: RossiQuestionBox,
      CommandGeneratorProvider: RossiCommandGeneratorProvider,
      SequenceStore: RossiSequenceStore,
      ActivityMachine.Activity == CommandGeneratorProvider.CommandGenerator.Activity,
      SideEffectMachine.SideEffect == CommandGeneratorProvider.CommandGenerator.SideEffect,
      ComputationMachine.Computation == CommandGeneratorProvider.CommandGenerator.Computation,
      QuestionBox.Question == CommandGeneratorProvider.CommandGenerator.Question {
    private let activityMachine: ActivityMachine
    private let sideEffectMachine: SideEffectMachine
    private let computationMachine: ComputationMachine
    private let questionBox: QuestionBox
    
    private let commandGeneratorProvider: CommandGeneratorProvider
    
    private var sequenceStore: SequenceStore
    private var activeCommandGenerator: CommandGeneratorProvider.CommandGenerator?
    
    private var state: State
    private var isResetting: Bool
    private var isReloading: Bool
    
    private var isFastForwardingRequested: Bool
    
    public init(
        activityMachine: ActivityMachine,
        sideEffectMachine: SideEffectMachine,
        computationMachine: ComputationMachine,
        questionBox: QuestionBox,
        commandGeneratorProvider: CommandGeneratorProvider,
        sequenceStore: SequenceStore
    ) {
        self.activityMachine = activityMachine
        self.sideEffectMachine = sideEffectMachine
        self.computationMachine = computationMachine
        self.questionBox = questionBox
        self.commandGeneratorProvider = commandGeneratorProvider
        
        self.sequenceStore = sequenceStore
        self.activeCommandGenerator = nil
        
        self.state = .idle
        self.isResetting = false
        self.isReloading = false
        
        self.isFastForwardingRequested = false
    }
    
    public func forward() {
        guard !isReloading && !isResetting else {
            return
        }
        
        switch state {
        case .idle:
            state = .running
            Task { await advance() }
            
        case .waitingForActivityCompletion, .sleeping:
            fastForward()
            
        case .running, .waitingForSideEffectCompletion, .waitingForComputationCompletion, .waitingForAnswer:
            return
        }
    }
    
    public func submitAnswer(answer: Any?) {
        guard !isReloading && !isResetting else {
            return
        }
        
        guard case .waitingForAnswer = state else {
            return
        }
        
        questionBox.hide()
        sequenceStore.track(value: answer)
        
        state = .running
        Task { await advance() }
    }
    
    private func advance() async {
        let command = await activeCommandGenerator?.generate(payload: sequenceStore.last)
        
        if isResetting {
            await performReset()
            return
        }
        
        guard let command else {
            state = .idle
            return
        }
        
        switch command {
        case .runActivity(let activity):
            state = .waitingForActivityCompletion
            await activityMachine.run(activity: activity)
            await notifyActivityCompletion()
            
        case .runSideEffect(let sideEffect):
            state = .waitingForSideEffectCompletion
            await sideEffectMachine.run(sideEffect: sideEffect)
            await notifySideEffectCompletion()
            
        case .runComputation(let computation):
            state = .waitingForComputationCompletion
            let payload = await computationMachine.run(computation: computation)
            await notifyComputationCompletion(payload: payload)
            
        case .askQuestion(let question):
            state = .waitingForAnswer
            questionBox.ask(question: question)
            questionBox.show()
            
        case .sleep(let duration):
            let timeoutHandle = TimeoutHandle(duration: duration)
            state = .sleeping(timeoutHandle: timeoutHandle)
            await timeoutHandle.wait()
            await notifySleepCompletion()
            
        case .halt:
            sequenceStore.track(value: nil)
            state = .idle
        }
    }
    
    private func fastForward() {
        guard !isFastForwardingRequested else {
            return
        }
        
        isFastForwardingRequested = true
        
        switch state {
        case .waitingForActivityCompletion:
            activityMachine.notifyFastForwarding()
            
        case .sleeping(let timeoutHandle):
            timeoutHandle.notifyCompleting()
            
        default:
            return
        }
    }
    
    private func notifyActivityCompletion() async {
        if isResetting {
            await performReset()
            return
        }
        
        sequenceStore.track(value: nil)
        isFastForwardingRequested = false
        
        state = .running
        await advance()
    }
    
    private func notifySideEffectCompletion() async {
        if isResetting {
            await performReset()
            return
        }
        
        sequenceStore.track(value: nil)
        
        state = .running
        await advance()
    }
    
    private func notifyComputationCompletion(payload: Any?) async {
        if isResetting {
            await performReset()
            return
        }
        
        sequenceStore.track(value: payload)
        
        state = .running
        await advance()
    }
    
    private func notifySleepCompletion() async {
        if isResetting {
            await performReset()
            return
        }
        
        sequenceStore.track(value: nil)
        
        state = .running
        await advance()
    }
    
    public func reset() {
        guard !isReloading && !isResetting else {
            return
        }
        
        isResetting = true
        
        switch state {
        case .idle, .waitingForAnswer:
            Task { await performReset() }
            
        case .running:
            return
            
        case .waitingForActivityCompletion, .sleeping:
            fastForward()
            
        case .waitingForSideEffectCompletion:
            sideEffectMachine.notifyCancellation()
            
        case .waitingForComputationCompletion:
            computationMachine.notifyCancellation()
        }
    }
    
    private func performReset() async {
        activityMachine.reset()
        sideEffectMachine.reset()
        computationMachine.reset()
        questionBox.hide()
        
        sequenceStore.clear()
        await activeCommandGenerator?.reset()
        
        isFastForwardingRequested = false
        isResetting = false
        state = .idle
    }
    
    public func reload() async {
        guard !isReloading && !isResetting else {
            return
        }
        
        switch state {
        case .idle, .waitingForAnswer:
            break
            
        default:
            return
        }
        
        isReloading = true
        
        if case .waitingForAnswer = state {
            questionBox.hide()
        }
        
        if let newCommandGenerator = await commandGeneratorProvider.provide() {
            var payload: Any? = nil
            
            for value in sequenceStore.sequence {
                _ = await newCommandGenerator.generate(payload: payload)
                payload = value
            }
            
            if
                case .waitingForAnswer = state,
                let command = await newCommandGenerator.generate(payload: payload),
                case .askQuestion(let question) = command
            {
                questionBox.ask(question: question)
            }
            
            activeCommandGenerator = newCommandGenerator
        }
        
        if case .waitingForAnswer = state {
            questionBox.show()
        }
        
        isReloading = false
    }
    
    private enum State {
        case idle
        case running
        case waitingForActivityCompletion
        case waitingForSideEffectCompletion
        case waitingForComputationCompletion
        case waitingForAnswer
        case sleeping(timeoutHandle: TimeoutHandle)
    }
}
