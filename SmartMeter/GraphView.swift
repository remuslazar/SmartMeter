//
//  GraphView.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

protocol GraphViewDatasource {
     func graphViewgetSample(x: Int) -> PowerMeter.History.PowerSample?
     func graphViewgetSampleCount() -> Int
}

class GraphView: UIView {
    
    var datasource: GraphViewDatasource?
    var maxY = 2000

    struct DrawConstants {
        static let lineWidth:CGFloat = 1.5
    }
    
    override func drawRect(rect: CGRect) {
        if datasource == nil { return }
        if datasource!.graphViewgetSampleCount() < 2 { return }

        let path = UIBezierPath()
        var lastPoint: CGPoint?

        let xScaleFactor: CGFloat = bounds.width / CGFloat(datasource!.graphViewgetSampleCount()-1)
        let yScaleFactor: CGFloat = bounds.height / CGFloat(maxY)
        
        for index in 0..<datasource!.graphViewgetSampleCount() {
            let sample = datasource?.graphViewgetSample(index)
            if let value = sample?.value {
                let x = CGFloat(index) * xScaleFactor
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
        UIColor.blackColor().set()
        path.lineWidth = DrawConstants.lineWidth
        path.stroke()
    }

}
