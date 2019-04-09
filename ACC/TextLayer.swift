//
//  TextLayer.swift
//  ACC
//
//  Created by Hung-Yun Liao on 7/10/16.
//  Copyright © 2016 Hung-Yun Liao. All rights reserved.
//

import UIKit

class TextLayer: CATextLayer {
    /// Indicate the color of the grid line.
    @IBInspectable
    var textColor: UIColor = UIColor.black {
        didSet {
            self.foregroundColor = textColor.cgColor
            self.setNeedsDisplay()
        }
    }
    
    var origin = ThreeAxesSystem<CGFloat>(x: 0, y: 0, z: 0)
    
    var scaleValue: Double = 1.0 {
        didSet {
            updateUI()
        }
    }
    
    init(frame: CGRect) {
        super.init()
        self.frame = frame
        self.foregroundColor = textColor.cgColor
        self.backgroundColor = UIColor.clear.cgColor
        
    }
    
    internal convenience required init?(coder aDecoder: NSCoder) {
        self.init(frame: CGRect.zero)
    }
    
    override var frame: CGRect {
        didSet {
            updateUI()
            updateBounds(rect: bounds)
        }
    }
    
    func setOrigin(x: Double, y: Double) {
        origin.x = CGFloat(x)
        origin.y = CGFloat(y)
        updateUI()
    }
    
    private func showIntIfCan(aDouble: Double) -> String {
        return aDouble.truncatingRemainder(dividingBy: 1) != 0 ? "\(aDouble)" : "\(Int(aDouble))"
    }
    
    private func updateUI() {
        
        self.sublayers?.removeAll()
        
        let centerPoint = CGPoint(x: origin.x, y: origin.y)
        
        for i in 0..<Int(bounds.width) {
            
            let shift: CGFloat
            if i%2 == 0 {
                shift = 0
            } else {
                shift = -15
            }
            
            let positiveXNums = drawTextLayer(frame: CGRect(x: -3 + centerPoint.x + CGFloat(i)*20, y: centerPoint.y + shift, width: 30, height: 30), printText: showIntIfCan(aDouble: Double(i) * scaleValue))
            self.addSublayer(positiveXNums)
            
            if i == 0 { continue }
            
            let negativeXNums = drawTextLayer(frame: CGRect(x: -3 + centerPoint.x + CGFloat(-i)*20, y: centerPoint.y + shift, width: 30, height: 30), printText: showIntIfCan(aDouble: Double(-i) * scaleValue))
            self.addSublayer(negativeXNums)
        }
        
        for i in 0..<Int(bounds.height) {
            
            if i == 0 { continue }
            
            let positiveYNums = drawTextLayer(frame: CGRect(x: -20 + centerPoint.x, y: -8 + centerPoint.y + CGFloat(-i)*20 , width: 30, height: 30), printText: showIntIfCan(aDouble: Double(i) * scaleValue))
            self.addSublayer(positiveYNums)
            
            let negativeYNums = drawTextLayer(frame: CGRect(x: -25 + centerPoint.x, y: -8 + centerPoint.y + CGFloat(i)*20 , width: 30, height: 30), printText: showIntIfCan(aDouble: Double(-i) * scaleValue))
            self.addSublayer(negativeYNums)
        }
    }
    
    private func drawTextLayer(frame: CGRect, printText: String) -> CATextLayer {
        let text: CATextLayer = CATextLayer()
        text.fontSize = 10
        text.frame = frame
        text.string = printText
        text.foregroundColor = UIColor.black.cgColor
        return text
    }
    
    private func updateBounds(rect: CGRect) {
        
    }
    
}
