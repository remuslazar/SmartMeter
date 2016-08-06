//
//  AxesDrawer.swift
//  SmartMeter
//
//  Created by Remus Lazar on 22.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

class AxesDrawer: UIView {

    private struct Constants {
        static let LabelHorizontalSpacing: CGFloat = 120
        static let LabelVerticalSpacing: CGFloat = 60
        static let XStepValueShouldBeMultipleOf: CGFloat = 60 // seconds
        static let YStepValueShouldBeMultipleOf: CGFloat = 100
        static let XScaleMarginBottom: CGFloat = 42
        static let YScaleMarginLeft: CGFloat = 8
        static let LegendColor: UIColor = UIColor.lightGrayColor()
    }

    private func drawText(text: String, toPoint point: CGPoint) {
        let attributes = [
            NSFontAttributeName : UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote),
            NSForegroundColorAttributeName : Constants.LegendColor
        ]

        let textRect = CGRect(origin: point, size: text.sizeWithAttributes(attributes))
        text.drawInRect(textRect, withAttributes: attributes)
    }
    
    private func drawY(bounds: CGRect, minY: CGFloat, maxY: CGFloat) {
        let maximumNumberOfLabels = bounds.height / Constants.LabelVerticalSpacing
        let minStepValue = maxY / maximumNumberOfLabels
        let stepValue = minStepValue.multipleOf(Constants.YStepValueShouldBeMultipleOf)
        
        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        
        for yValue in stepValue.stride(to: maxY, by: stepValue) {
            let y = bounds.height - (yValue / maxY * bounds.height)
            if let label = formatter.stringFromNumber(yValue)?.stringByAppendingString("W") {
                drawText(label, toPoint: CGPoint(x: Constants.YScaleMarginLeft, y: y))
            }
        }
    }
    
    private func drawX(bounds: CGRect, minX: NSDate, maxX: NSDate) {
        let timeInterval = maxX.timeIntervalSinceDate(minX)
        let maximumNumberOfLabels = bounds.width / Constants.LabelHorizontalSpacing
        let minStepValue = CGFloat(timeInterval) / maximumNumberOfLabels
        let stepValue = minStepValue.multipleOf(Constants.XStepValueShouldBeMultipleOf)
        
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.NoStyle
        formatter.timeStyle = NSDateFormatterStyle.ShortStyle
        
        let seconds = NSCalendar.currentCalendar().component(.Second, fromDate: minX)
        
        for xValue in (60.0 - CGFloat(seconds)).stride(to: CGFloat(timeInterval), by: stepValue) {
            let x = xValue / CGFloat(timeInterval) * bounds.width
            let location = CGPoint(x: x, y: bounds.height - Constants.XScaleMarginBottom)
            let date = minX.dateByAddingTimeInterval(NSTimeInterval(xValue))
            drawText(formatter.stringFromDate(date), toPoint: location)
        }
    }
    
    
    func drawAxesInRect(bounds: CGRect, minX: NSDate, maxX: NSDate, minY: CGFloat = 0, maxY: CGFloat) {

        drawX(bounds, minX: minX, maxX: maxX)
        drawY(bounds, minY: minY, maxY: maxY)
    }
    
}

private extension CGFloat {
    func multipleOf(val: CGFloat) -> CGFloat {
        return ceil(self / val) * val
    }
}