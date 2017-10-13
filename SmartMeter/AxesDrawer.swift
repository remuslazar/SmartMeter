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
        static let LegendColor: UIColor = UIColor.lightGray
    }

    private func draw(text: String, toPoint point: CGPoint) {
        let attributes = [
            NSAttributedStringKey.font : UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote),
            NSAttributedStringKey.foregroundColor : Constants.LegendColor
        ]

        let textRect = CGRect(origin: point, size: text.size(withAttributes: attributes))
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawY(bounds: CGRect, minY: CGFloat, maxY: CGFloat) {
        let maximumNumberOfLabels = bounds.height / Constants.LabelVerticalSpacing
        let minStepValue = maxY / maximumNumberOfLabels
        let stepValue = minStepValue.multipleOf(Constants.YStepValueShouldBeMultipleOf)
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        
        for yValue in stride(from: stepValue, to: maxY, by: stepValue) {
            let y = bounds.height - (yValue / maxY * bounds.height)
            if let label = formatter.string(from: NSNumber(floatLiteral: Double(yValue))) {
                draw(text: label + "W", toPoint: CGPoint(x: Constants.YScaleMarginLeft, y: y))
            }
        }
    }
    
    private func drawX(bounds: CGRect, minX: Date, maxX: Date) {
        let timeInterval = maxX.timeIntervalSince(minX)
        let maximumNumberOfLabels = bounds.width / Constants.LabelHorizontalSpacing
        let minStepValue = CGFloat(timeInterval) / maximumNumberOfLabels
        let stepValue = minStepValue.multipleOf(Constants.XStepValueShouldBeMultipleOf)
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.none
        formatter.timeStyle = DateFormatter.Style.short
        
        let seconds = (Calendar.current as NSCalendar).component(.second, from: minX)
        
        for xValue in stride(from: (60.0 - CGFloat(seconds)), to: CGFloat(timeInterval), by: stepValue) {
            let x = xValue / CGFloat(timeInterval) * bounds.width
            let location = CGPoint(x: x, y: bounds.height - Constants.XScaleMarginBottom)
            let date = minX.addingTimeInterval(TimeInterval(xValue))
            draw(text: formatter.string(from: date), toPoint: location)
        }
    }
    
    
    func drawAxes(inRect bounds: CGRect, minX: Date, maxX: Date, minY: CGFloat = 0, maxY: CGFloat) {

        drawX(bounds: bounds, minX: minX, maxX: maxX)
        drawY(bounds: bounds, minY: minY, maxY: maxY)
    }
    
}

private extension CGFloat {
    func multipleOf(_ val: CGFloat) -> CGFloat {
        return ceil(self / val) * val
    }
}
