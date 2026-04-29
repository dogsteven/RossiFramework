//
//  Customizer.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import JavaScriptCore

public protocol GilbertaJSContextCustomizer {
    func prepareSetup(context: JSContext) async
    func teardownSetup(context: JSContext) async
    
    func prepareMain(context: JSContext) async
    func prepareSession(context: JSContext) async
}

extension Array: GilbertaJSContextCustomizer where Element: GilbertaJSContextCustomizer {
    public func prepareSetup(context: JSContext) async {
        for customizer in self {
            await customizer.prepareSetup(context: context)
        }
    }
    
    public func teardownSetup(context: JSContext) async {
        for customizer in self.reversed() {
            await customizer.teardownSetup(context: context)
        }
    }
    
    public func prepareMain(context: JSContext) async {
        for customizer in self {
            await customizer.prepareMain(context: context)
        }
    }
    
    public func prepareSession(context: JSContext) async {
        for customizer in self {
            await customizer.prepareSession(context: context)
        }
    }
}
