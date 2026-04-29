//
//  ModuleLoaderInjector.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation
import JavaScriptCore

public actor StatelessModuleLoaderInjector: GilbertaJSContextCustomizer {
    private let moduleDirectoryURL: URL
    private var sessionScriptCache: [String: String]
    
    public init(moduleDirectoryURL: URL) {
        self.moduleDirectoryURL = moduleDirectoryURL
        self.sessionScriptCache = [:]
    }
    
    public func prepareSetup(context: JSContext) {
        injectLoadModule(context: context)
    }
    
    public func teardownSetup(context: JSContext) {
        
    }
    
    public func prepareMain(context: JSContext) {
        injectLoadSessionModule(context: context)
    }
    
    public func prepareSession(context: JSContext) {
        sessionScriptCache.removeAll()
    }
    
    private func injectLoadModule(context: JSContext) {
        let loadModule: @convention(block) (String) -> JSValue? = { [unowned self] path in
            guard let currentContext = JSContext.current() else {
                return nil
            }
            
            let modulePath = self.moduleDirectoryURL.appending(component: path, directoryHint: .notDirectory)
            let moduleScript = (try? String(contentsOf: modulePath, encoding: .utf8)) ?? "async function* main(arguments) {}"
            
            let wrappedModuleScript = "(__arguments)=>{\(moduleScript);return main(__arguments);}"
            
            return currentContext.evaluateScript(wrappedModuleScript)
        }
        
        context.setObject(loadModule, forKeyedSubscript: "loadModule" as NSString)
    }
    
    private func injectLoadSessionModule(context: JSContext) {
        let loadSessionModule: @convention(block) (String) -> JSValue? = { [unowned self] path in
            guard let currentContext = JSContext.current() else {
                return nil
            }
            
            let modulePath = self.moduleDirectoryURL.appending(component: path, directoryHint: .notDirectory)
            var moduleScript = "async function* main(arguments) {}"
            
            if let cached = self.sessionScriptCache[path] {
                moduleScript = cached
            } else if let loaded = try? String(contentsOf: modulePath, encoding: .utf8) {
                moduleScript = loaded
                self.sessionScriptCache[path] = loaded
            }
            
            let wrappedModuleScript = "(__arguments)=>{\(moduleScript);return main(__arguments);}"
            
            return currentContext.evaluateScript(wrappedModuleScript)
        }
        
        context.setObject(loadSessionModule, forKeyedSubscript: "loadSessionModule" as NSString)
    }
}
