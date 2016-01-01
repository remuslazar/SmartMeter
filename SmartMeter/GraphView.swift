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

protocol GraphViewDelegate {
    func graphViewDidUpdateDraggedArea(powerAvg powerAvg: Double, timespan: Double)
}

class GraphView: UIView {
    
    private struct Constants {
        static let lineWidth:CGFloat = 1.5
        static let NumSamplesPerPixelRatio: CGFloat = 1.0 // 1.0 will fully use the retina resolution
        static let NumSamplesPerPixelRatioInPanOrZoomMode: CGFloat = 0.25
    }
    
    var datasource: GraphViewDatasource!
    var delegate: GraphViewDelegate!
    
    var calculateAreaMode = false {
        didSet {
            if !calculateAreaMode {
                selectedRect = nil
                setNeedsDisplay()
            }
        }
    }
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !calculateAreaMode
    }
    
    private let axesDrawer = AxesDrawer()

    var maxY: CGFloat {
        return CGFloat(datasource.graphViewGetMaxY())
    }
    
    private var dragStartingPoint: CGPoint?
    var selectedRect: CGRect?
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if !calculateAreaMode { return }
        if let touch = touches.first {
            dragStartingPoint = touch.locationInView(self)
            selectedRect = nil
            setNeedsDisplay()
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if !calculateAreaMode { return }
        dragStartingPoint = nil
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if !calculateAreaMode { return }
        if let touch = touches.first {
            if dragStartingPoint != nil {
                let dragEndPoint = touch.locationInView(self)
                selectedRect = CGRectStandardize(CGRectMake(
                    dragStartingPoint!.x, dragStartingPoint!.y,
                    dragEndPoint.x - dragStartingPoint!.x,
                    dragEndPoint.y - dragStartingPoint!.y
                    ))
                setNeedsDisplay()
            }
        }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        if !calculateAreaMode { return }
        selectedRect = nil
    }
    
    private func calculateArea() {
        
        func yValueForYCoodrdinate(y:CGFloat) -> Double {
            return Double(maxY * (bounds.height - y)/bounds.height)
        }
    
        if let selection = selectedRect {
            let xScaleFactor: CGFloat = bounds.width / CGFloat(datasource.graphViewgetSampleCount()-1)
            let x0 = Int(selection.minX / xScaleFactor)
            let x1 = Int(selection.maxX / xScaleFactor)
            var powerAvg = 0.0
            if x1 > x0 {
                let minY = yValueForYCoodrdinate(selection.maxY)
                let maxY = yValueForYCoodrdinate(selection.minY)
                for x in x0..<x1 {
                    if let y = datasource.graphViewgetSample(x, resample: 1)?.value {
                        powerAvg += min(Double(y), maxY) - minY
                    }
                }
                if let ts0 = datasource.graphViewgetSample(x0, resample: 1)?.timestamp,
                    let ts1 = datasource.graphViewgetSample(x1, resample: 1)?.timestamp {
                        powerAvg /= Double(x1-x0)
                        let deltaT = Double(ts1.timeIntervalSinceDate(ts0))
                        delegate?.graphViewDidUpdateDraggedArea(powerAvg: powerAvg, timespan: deltaT)
                }
            }
        }
    }
    
    override func drawRect(rect: CGRect) {
        if datasource == nil { return }
        if datasource.graphViewgetSampleCount() < 2 { return }

        let path = UIBezierPath()
        var lastPoint: CGPoint?

        let xScaleFactor: CGFloat = bounds.width / CGFloat(datasource.graphViewgetSampleCount()-1)
        let yScaleFactor: CGFloat = bounds.height / CGFloat(maxY)
        
        let step = Int(ceil(CGFloat(datasource.graphViewgetSampleCount()) /
            (bounds.width * contentScaleFactor * Constants.NumSamplesPerPixelRatio)))
        
        for var index = 0 ; index < datasource.graphViewgetSampleCount() ; index += step {
            let sample = datasource.graphViewgetSample(index, resample: step)
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
        path.lineWidth = Constants.lineWidth
        path.stroke()
        
        if let minX = datasource?.graphViewgetSample(0, resample: 1)?.timestamp,
            let maxX = datasource?.graphViewgetSample(datasource.graphViewgetSampleCount()-1, resample: 1)?.timestamp {
                axesDrawer.drawAxesInRect(bounds, minX: minX, maxX: maxX, minY: 0, maxY: maxY)
        }
        
        if let selection = selectedRect {
            let clip = path.copy() as! UIBezierPath
            clip.addLineToPoint(CGPoint(x: selection.maxX, y: bounds.height))
            clip.addLineToPoint(CGPoint(x: selection.minX, y: bounds.height))
            clip.closePath()
            clip.addClip()
            
            let rect = UIBezierPath(rect: selection)
            rect.lineWidth = Constants.lineWidth
            rect.stroke()
            UIColor.blueColor().setFill()
            rect.fill()
            calculateArea()
        }
        
    }
}
