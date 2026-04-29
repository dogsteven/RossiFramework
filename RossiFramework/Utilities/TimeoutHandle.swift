//
//  Timeout.swift
//  RossiFramework
//
//  Created by khoahuynhbach on 29/4/26.
//

import Foundation

@MainActor
public final class TimeoutHandle {
    private var task: Task<Void, Never>?
    
    public init(duration: TimeInterval) {
        self.task = Task {
            try? await Task.sleep(for: .seconds(duration))
        }
    }
    
    public func wait() async {
        await task?.value
    }
    
    public func notifyCompleting() {
        task?.cancel()
        task = nil
    }
}
