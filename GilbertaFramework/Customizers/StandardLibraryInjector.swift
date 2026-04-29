//
//  StandardLibraryInjector.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation
import JavaScriptCore

public actor StandardLibraryInjector: GilbertaJSContextCustomizer {
    private let standardLibraryURL: URL
    private var standardLibraryCode: String?
    
    public init(standardLibraryURL: URL) {
        self.standardLibraryURL = standardLibraryURL
        self.standardLibraryCode = nil
    }
    
    public func prepareSetup(context: JSContext) {
        
    }
    
    public func teardownSetup(context: JSContext) {
        
    }
    
    public func prepareMain(context: JSContext) {
        if standardLibraryCode == nil {
            standardLibraryCode = try? String(contentsOf: standardLibraryURL, encoding: .utf8)
        }
        
        if let standardLibraryCode {
            context.evaluateScript(standardLibraryCode)
        }
    }
    
    public func prepareSession(context: JSContext) async {
        
    }
    
    public func refresh() {
        standardLibraryCode = nil
    }
}
