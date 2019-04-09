//
//  MapView.swift
//  ACC
//
//  Created by Hung-Yun Liao on 6/8/16.
//  Copyright © 2016 Hung-Yun Liao. All rights reserved.
//

import UIKit


class MapView: UIView {
    
    /* MARK: Private instances */
    // Not yet implement "Z" axis
    private var routePath = UIBezierPath()
    private var pathPoints = [ThreeAxesSystem<CGFloat>]() // an array that keeps the original path points which are used to re-draw the routePath when the scale is changed.
    private var previousOrigin = ThreeAxesSystem<CGFloat>(x: 0, y: 0, z: 0)
    private var currentOrigin = ThreeAxesSystem<CGFloat>(x: 0, y: 0, z: 0)
    private var previousPoint = ThreeAxesSystem<CGFloat>(x: 0, y: 0, z: 0)
    private var currentPoint = ThreeAxesSystem<CGFloat>(x: 0, y: 0, z: 0)
    private var resetOffset = ThreeAxesSystem<CGFloat>(x: 0, y: 0, z: 0)
    
    private var isResetScale = false
    private var accumulatedScale: CGFloat = 1.0
    
    /* MARK: Public APIs */
    func setScale(scale: Double) {
        accumulatedScale *= CGFloat(scale)
        threeAxisSysOperation(threeAxisSysPoint: &resetOffset, operation: .multiply, aValue: CGFloat(scale))
        
        if !pathPoints.isEmpty {
            for i in 0..<pathPoints.count {
                threeAxisSysOperation(threeAxisSysPoint: &pathPoints[i], operation: .multiply, aValue: CGFloat(scale))
            }
            
            threeAxisSysOperation(threeAxisSysPoint: &currentPoint, operation: .assign, operandPoint: pathPoints[pathPoints.count - 1])
            isResetScale = true
        }
        setNeedsDisplay()
    }
    
    func setOrigin(x: Double, y: Double) {
        
        threeAxisSysOperation(threeAxisSysPoint: &previousOrigin, operation: .assign, operandPoint: currentOrigin)
        threeAxisSysOperation(
            threeAxisSysPoint: &currentOrigin,
            operation: .assign,
            operandPoint: ThreeAxesSystem<CGFloat>(x: CGFloat(x), y: CGFloat(y), z: CGFloat(0))
        )
        
        if !pathPoints.isEmpty {
            isResetScale = true
        }
        
        setNeedsDisplay()
    }
    
    func movePointTo(x: Double, y: Double) {
        
        threeAxisSysOperation(threeAxisSysPoint: &previousPoint, operation: .assign, operandPoint: currentPoint)
        
        let incomingPoint =
            ThreeAxesSystem<CGFloat>(x: CGFloat(x)*accumulatedScale - resetOffset.x, y: CGFloat(y)*accumulatedScale - resetOffset.y, z: 0)
        threeAxisSysOperation(threeAxisSysPoint: &currentPoint, operation: .assign, operandPoint: incomingPoint)
        
        pathPoints.append(ThreeAxesSystem<CGFloat>(x: currentPoint.x, y: currentPoint.y, z: 0)) // z has not yet been implemented
        setNeedsDisplay()
    }
    
    func cleanPath() {
        
        if !pathPoints.isEmpty {
            threeAxisSysOperation(threeAxisSysPoint: &resetOffset, operation: .add, operandPoint: currentPoint)
        }
        
        threeAxisSysOperation(threeAxisSysPoint: &currentPoint, operation: .assign, aValue: 0)
        threeAxisSysOperation(threeAxisSysPoint: &previousPoint, operation: .assign, aValue: 0)
        
        routePath.removeAllPoints()
        pathPoints.removeAll()
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        
        if isResetScale {
            routePath.removeAllPoints()
            for i in 0..<(pathPoints.count - 1) {
                routePath.move(to: CGPoint(x: pathPoints[i].x + currentOrigin.x, y: pathPoints[i].y + currentOrigin.y))
                routePath.addLine(to: CGPoint(x: pathPoints[i+1].x + currentOrigin.x, y: pathPoints[i+1].y + currentOrigin.y))
            }
            isResetScale = false
            
        } else {
            routePath.move(to: CGPoint(x: previousPoint.x + currentOrigin.x, y: previousPoint.y + currentOrigin.y))
            routePath.addLine(to: CGPoint(x: currentPoint.x + currentOrigin.x, y: currentPoint.y + currentOrigin.y))
        }
        
        let circle =
            getCircle(atCenter: CGPoint(x: currentPoint.x + currentOrigin.x, y: currentPoint.y + currentOrigin.y), radius: CGFloat(5))
        
        UIColor.black.set()
        routePath.stroke()
        
        UIColor.black.set()
        circle.fill()
    }
}

func getCircle(atCenter center: CGPoint, radius: CGFloat) -> UIBezierPath {
    return UIBezierPath(arcCenter: center, radius: radius, startAngle: 0.0, endAngle: CGFloat(2*Double.pi), clockwise: false)
}

func getLinePath(startPoint: CGPoint, endPoint: CGPoint) -> UIBezierPath {
    
    let linePath = UIBezierPath()
    linePath.move(to: startPoint)
    linePath.addLine(to: endPoint)
    
    return linePath
}

func threeAxisSysOperation( threeAxisSysPoint: inout ThreeAxesSystem<CGFloat>, operation: Operation, aValue: CGFloat) {
    let threeAxisSysPointWithValue = ThreeAxesSystem<CGFloat>(x: aValue, y: aValue, z: aValue)
    threeAxisSysOperation(threeAxisSysPoint: &threeAxisSysPoint, operation: operation, operandPoint: threeAxisSysPointWithValue)
}

func threeAxisSysOperation( threeAxisSysPoint: inout ThreeAxesSystem<CGFloat>, operation: Operation, operandPoint: ThreeAxesSystem<CGFloat>) {
    switch operation {
    case .assign:
        threeAxisSysPoint.x = operandPoint.x
        threeAxisSysPoint.y = operandPoint.y
        threeAxisSysPoint.z = operandPoint.z
    case .add:
        threeAxisSysPoint.x += operandPoint.x
        threeAxisSysPoint.y += operandPoint.y
        threeAxisSysPoint.z += operandPoint.z
    case .minus:
        threeAxisSysPoint.x -= operandPoint.x
        threeAxisSysPoint.y -= operandPoint.y
        threeAxisSysPoint.z -= operandPoint.z
    case .multiply:
        threeAxisSysPoint.x *= operandPoint.x
        threeAxisSysPoint.y *= operandPoint.y
        threeAxisSysPoint.z *= operandPoint.z
    case .divide:
        threeAxisSysPoint.x /= operandPoint.x
        threeAxisSysPoint.y /= operandPoint.y
        threeAxisSysPoint.z /= operandPoint.z
    }
}

enum Operation {
    case assign     // =
    case add        // +=
    case minus      // -=
    case multiply   // *=
    case divide     // /=
}
