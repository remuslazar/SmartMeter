//
//  PowerGraphEngine.swift
//  SmartMeter
//
//  Created by Remus Lazar on 21.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import Foundation

class PowerGraphEngine: GraphViewDatasource {

    init(history: PowerMeter.History) {
        self.history = history
    }
    
    private let history: PowerMeter.History

    var scaleX = 1.0 {
        didSet {
            scaleX = max(1.0, scaleX) // dont let scale be < 1.0
            // center the graph after scaling
            offsetX += Int((scaleX - oldValue) * Double(numVisibleSamples) / 2)
        }
    }
    
    var offsetX: Int = 0 {
        didSet {
            offsetX = abs(offsetX) // should be always positive
            if rightPadding < 0 { offsetX += rightPadding }
        }
    }
    
    var maxY: Double = 2000
    
    private var numVisibleSamples: Int {
        return Int(Double(history.count ?? 0) / scaleX)
    }
    
    private var rightPadding: Int {
        return history.count - numVisibleSamples - offsetX
    }
    
    func graphViewgetSampleCount() -> Int {
        return numVisibleSamples
    }
    
    func graphViewgetSample(x: Int, resample: Int) -> PowerMeter.History.PowerSample? {
        let index = x + offsetX
        if resample == 1 { return history.getSample(index) }
        return history.getSample(index, resample: resample)
    }
    
    func graphViewGetMaxY() -> Double {
        return maxY
    }
    
    
}