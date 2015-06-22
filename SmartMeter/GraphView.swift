//
//  GraphView.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

protocol GraphViewDatasource {
    func graphViewGetMaxY() -> Double
    func graphViewgetSample(x: Int, resample: Int) -> PowerMeter.History.PowerSample?
    func graphViewgetSampleCount() -> Int
}

class GraphView: UIView {
    
    private struct Constants {
        static let lineWidth:CGFloat = 1.5
        static let NumSamplesPerPixelRatio: CGFloat = 1.0 // 1.0 will fully use the retina resolution
        static let NumSamplesPerPixelRatioInPanOrZoomMode: CGFloat = 0.25
    }
    
    var datasource: GraphViewDatasource?
    
    private let axesDrawer = AxesDrawer()

    var maxY: CGFloat {
        return CGFloat(datasource!.graphViewGetMaxY())
    }
    
    override func drawRect(rect: CGRect) {
        if datasource == nil { return }
        if datasource!.graphViewgetSampleCount() < 2 { return }

        let path = UIBezierPath()
        var lastPoint: CGPoint?

        let xScaleFactor: CGFloat = bounds.width / CGFloat(datasource!.graphViewgetSampleCount()-1)
        let yScaleFactor: CGFloat = bounds.height / CGFloat(maxY)
        
        let step = Int(ceil(CGFloat(datasource!.graphViewgetSampleCount()) /
            (bounds.width * contentScaleFactor * Constants.NumSamplesPerPixelRatio)))
        
        for var index = 0 ; index < datasource!.graphViewgetSampleCount() ; index += step {
            let sample = datasource?.graphViewgetSample(index, resample: step)
            if let value = sample?.value {
                let x = CGFloat(index) * xScaleFactor
                if x.isNormal {
                    let y = CGFloat(value) * yScaleFactor
                    let newPoint = CGPoint(x: x, y: bounds.height-y)
                    
                    if lastPoint != nil {
                        path.addLineToPoint(newPoint)
                    } else {
                        path.moveToPoint(newPoint)
                    }
                    lastPoint = newPoint
                }
            }
        }
        
        UIColor.blackColor().set()
        path.lineWidth = Constants.lineWidth
        path.stroke()
        
        if let minX = datasource?.graphViewgetSample(0, resample: 1)?.timestamp,
            let maxX = datasource?.graphViewgetSample(datasource!.graphViewgetSampleCount()-1, resample: 1)?.timestamp
        {
            axesDrawer.drawAxesInRect(bounds, minX: minX, maxX: maxX, minY: 0, maxY: maxY)
        }
    }
}
