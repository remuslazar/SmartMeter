//
//  GraphView.swift
//  SmartMeter
//
//  Created by Remus Lazar on 20.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

protocol GraphViewDatasource {
    func graphViewgetSample(x: Int, resample: Int) -> PowerMeter.History.PowerSample?
     func graphViewgetSampleCount() -> Int
}

class GraphView: UIView {
    
    private struct Constants {
        static let LabelHorizontalSpacing: CGFloat = 120
        static let LabelVerticalSpacing: CGFloat = 60
        static let XStepValueShouldBeMultipleOf: CGFloat = 60 // seconds
        static let YStepValueShouldBeMultipleOf: CGFloat = 100
        static let XScaleMarginBottom: CGFloat = 42
        static let YScaleMarginLeft: CGFloat = 8
        static let LegendColor: UIColor = UIColor.lightGrayColor()
        static let NumSamplesPerPixelRatio: CGFloat = 1.0 // 1.0 will fully use the retina resolution
        static let NumSamplesPerPixelRatioInPanOrZoomMode: CGFloat = 0.25
    }
    
    func zoom(gesture: UIPinchGestureRecognizer) {
        switch (gesture.state) {
        case .Changed:
            // we want to consider direction of the pinch to determine if we want to
            // scale in the x or/and y direction
            let fingers = [
                gesture.locationOfTouch(0, inView: self),
                gesture.locationOfTouch(1, inView: self)
            ]
        
            let deltaX = abs(fingers[0].x - fingers[1].x)
            let deltaY = abs(fingers[0].y - fingers[1].y)
            let scale: CGFloat = 1.0 - gesture.scale
            let scaleX = 1.0 - deltaX / (deltaX + deltaY) * scale
            let scaleY = 1.0 - deltaY / (deltaX + deltaY) * scale

            maxY /= scaleY
            
            gesture.scale = 1.0
            
        default: break
        }
    }
    
    var datasource: GraphViewDatasource?
    var maxY: CGFloat = 2000 { didSet { setNeedsDisplay() } }

    
    var minX: NSDate? {
        if let firstSamle =  datasource?.graphViewgetSample(0, resample: 1) {
            return firstSamle.timestamp
        }
        return nil
    }

    var maxX: NSDate? {
        if let count =  datasource?.graphViewgetSampleCount() {
            return minX?.dateByAddingTimeInterval(NSTimeInterval(count))
        }
        return nil
    }

    struct DrawConstants {
        static let lineWidth:CGFloat = 1.5
    }
    
    private func drawLegends() {

        let attributes = [
            NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote),
            NSForegroundColorAttributeName : Constants.LegendColor
        ]

        // X Legend
        if let timeInterval = maxX?.timeIntervalSinceDate(minX!) {
            let maximumNumberOfLabels = bounds.width / Constants.LabelHorizontalSpacing
            let minStepValue = CGFloat(timeInterval) / maximumNumberOfLabels
            let stepValue = minStepValue.multipleOf(Constants.XStepValueShouldBeMultipleOf)
            
            let formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.NoStyle
            formatter.timeStyle = NSDateFormatterStyle.ShortStyle
            
            let seconds = NSCalendar.currentCalendar().component(.CalendarUnitSecond, fromDate: minX!)
            
            for var xValue: CGFloat = 60.0 - CGFloat(seconds) ; xValue < CGFloat(timeInterval) ; xValue += stepValue {
                let x = xValue / CGFloat(timeInterval) * bounds.width
                let location = CGPoint(x: x, y: bounds.height - Constants.XScaleMarginBottom)
                
                let date = minX?.dateByAddingTimeInterval(NSTimeInterval(xValue))
                let label = formatter.stringFromDate(date!)
                var textRect = CGRect(origin: location, size: label.sizeWithAttributes(attributes))
                label.drawInRect(textRect, withAttributes: attributes)
            }
            
        }

        // Y Legend
        let maximumNumberOfLabels = bounds.height / Constants.LabelVerticalSpacing
        let minStepValue = maxY / maximumNumberOfLabels
        let stepValue = minStepValue.multipleOf(Constants.YStepValueShouldBeMultipleOf)
        
        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        
        for var yValue: CGFloat = stepValue ; yValue < maxY ; yValue += stepValue {
            let y = bounds.height - (yValue / maxY * bounds.height)
            let location = CGPoint(x: Constants.YScaleMarginLeft, y: y)
            if let label = formatter.stringFromNumber(yValue)?.stringByAppendingString("W") {
                var textRect = CGRect(origin: location, size: label.sizeWithAttributes(attributes))
                label.drawInRect(textRect, withAttributes: attributes)
            }
        }
    
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
        drawLegends()
    }
}

extension CGFloat {
    func multipleOf(val: CGFloat) -> CGFloat {
        return ceil(self / val) * val
    }
}
