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
            scaleX = max(1.0, min(Double(graphViewgetSampleCount()/2) ,scaleX)) // dont let scale be < 1.0
            // center the graph after scaling
            offsetX += (scaleX - oldValue) * numVisibleSamples / 2
        }
    }
    
    var offsetX = 0.0 {
        didSet {
            offsetX = max(0,offsetX) // should be always positive
            if rightPadding < 0 { offsetX += rightPadding }
        }
    }
    
    var maxY: Double = 2000
    
    private var numVisibleSamples: Double {
        return Double(history.count) / scaleX
    }
    
    private var rightPadding: Double {
        return Double(history.count) - numVisibleSamples - offsetX
    }
    
    func graphViewgetSampleCount() -> Int {
        // just in case, assert that it is <= history.count
        return min(Int(round(numVisibleSamples)), history.count)
    }
    
    func graphViewgetSample(_ x: Int, resample: Int) -> PowerMeter.History.PowerSample? {
        let index = x + Int(round(offsetX))
        if resample == 1 { return history.getSample(index) }
        return history.getSample(index, resample: resample)
    }
    
    func graphViewGetMaxY() -> Double {
        return maxY
    }
    
    func select(x1: Double, x2: Double, y0: Double) {
        print("x1: \(x1), x2: \(x2), y0: \(y0)")
    }
    
    
}
