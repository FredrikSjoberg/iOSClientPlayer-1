//
//  RateObserver.swift
//  Player
//
//  Created by Fredrik Sjöberg on 2018-02-27.
//  Copyright © 2018 emp. All rights reserved.
//

import Foundation

/// Wrapper for tracking a *KVO* token. Needs to be cancelled before the observer is deallocated
@available(*, introduced: 2.0.78, deprecated: 2.0.79, renamed: "UnmanagedPlayerObserver")
public class RateObserver {
    internal var playerObserver: PlayerObserver
    
    internal init(playerObserver: PlayerObserver) {
        self.playerObserver = playerObserver
    }
    
    /// Cancels the underlying *key value observation*
    public func cancel() {
        playerObserver.stopObservingAll()
    }
}
