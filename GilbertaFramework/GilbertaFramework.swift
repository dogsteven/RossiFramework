//
//  GilbertaFramework.swift
//  GilbertaFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation
import JavaScriptCore
import RossiFramework

public actor GilbertaCommandGeneratorProvider<Activity, SideEffect, Computation, Question, CommandDecoder>: RossiCommandGeneratorProvider
where CommandDecoder: RossiCommandDecoder,
      CommandDecoder.Activity == Activity,
      CommandDecoder.SideEffect == SideEffect,
      CommandDecoder.Computation == Computation,
      CommandDecoder.Question == Question,
      Activity: Sendable,
      SideEffect: Sendable,
      Computation: Sendable,
      Question: Sendable {
    public typealias CommandGenerator = GilbertaCommandGenerator<Activity, SideEffect, Computation, Question, CommandDecoder>
    
    private let customizer: GilbertaJSContextCustomizer
    private let decoder: CommandDecoder
    
    public init(
        customizer: GilbertaJSContextCustomizer,
        decoder: CommandDecoder
    ) {
        self.customizer = customizer
        self.decoder = decoder
    }
    
    public func provide() async -> GilbertaCommandGenerator<Activity, SideEffect, Computation, Question, CommandDecoder>? {
        guard let context = await buildContext() else {
            return nil
        }
        
        return GilbertaCommandGenerator(
            context: context,
            customizer: customizer,
            decoder: decoder
        )
    }
    
    private func buildContext() async -> JSContext? {
        guard let context = JSContext() else {
            return nil
        }
        
        guard
            let setupFunction = context.objectForKeyedSubscript("setup"), !setupFunction.isUndefined
        else {
            return nil
        }
        
        guard let setupPromise = setupFunction.call(withArguments: []), setupPromise.isObject else {
            return nil
        }
        
        await customizer.prepareSetup(context: context)
        
        await withCheckedContinuation { continuation in
            let resume: @convention(block) () -> Void = { continuation.resume() }
            
            setupPromise
                .invokeMethod("then", withArguments: [resume])
                .invokeMethod("catch", withArguments: [resume])
        }
        
        await customizer.teardownSetup(context: context)
        await customizer.prepareMain(context: context)
        
        return context
    }
}

public actor GilbertaCommandGenerator<Activity, SideEffect, Computation, Question, CommandDecoder>: RossiCommandGenerator
where CommandDecoder: RossiCommandDecoder,
      CommandDecoder.Activity == Activity,
      CommandDecoder.SideEffect == SideEffect,
      CommandDecoder.Computation == Computation,
      CommandDecoder.Question == Question,
      Activity: Sendable,
      SideEffect: Sendable,
      Computation: Sendable,
      Question: Sendable {
    private let context: JSContext
    private let customizer: GilbertaJSContextCustomizer
    private let decoder: CommandDecoder
    
    private var activeGenerator: JSValue?
    
    public init(
        context: JSContext,
        customizer: GilbertaJSContextCustomizer,
        decoder: CommandDecoder
    ) {
        self.context = context
        self.customizer = customizer
        self.decoder = decoder
        self.activeGenerator = nil
    }
    
    public func generate(payload: Any?) async -> RossiCommand<Activity, SideEffect, Computation, Question>? {
        guard let generator = activeGenerator else {
            return nil
        }
 
        guard let nextPromiseResult = generator.invokeMethod("next", withArguments: [payload ?? NSNull()]), nextPromiseResult.isObject else {
            return nil
        }
        
        let nextResult: JSValue? = await withCheckedContinuation { continuation in
            let resolve: @convention(block) (JSValue?) -> Void = { value in continuation.resume(returning: value) }
            let reject: @convention(block) () -> Void = { continuation.resume(returning: nil) }
            
            nextPromiseResult
                .invokeMethod("then", withArguments: [resolve])
                .invokeMethod("catch", withArguments: [reject])
        }
        
        guard let done = nextResult?.objectForKeyedSubscript("done")?.toBool(), !done else {
            return nil
        }
 
        guard let value = nextResult?.objectForKeyedSubscript("value")?.toString() else {
            return nil
        }
 
        return decoder.decode(message: value)
    }
    
    
    public func reset() async {
        guard let mainFunction = context.objectForKeyedSubscript("main") else {
            return
        }
        
        await customizer.prepareSession(context: context)
        
        activeGenerator = mainFunction.call(withArguments: [])
    }
}

