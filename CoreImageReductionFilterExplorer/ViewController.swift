//
//  ViewController.swift
//  CoreImageReductionFilterExplorer
//
//  Created by Simon Gladman on 22/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{
    let imageSide = CGFloat(640)
    let widgetsHeight = CGFloat(100)
    
    let engineImage = CIImage(image:
        UIImage(named: "engine.jpg")!)!
    
    let mainImageView = UIImageView()
    let histogramView = ImageView()
    let swatch = UIView()
    
    lazy var mainStackView: UIStackView =
    {
        [unowned self] in
        
        let stackView = UIStackView(arrangedSubviews: [
            self.mainImageView,
            self.bottomStackView])
        
        stackView.distribution = .equalSpacing
        stackView.axis = .vertical
        stackView.alignment = .center
        
        return stackView
    }()
    
    lazy var progressStackView: UIStackView =
    {
        [unowned self] in
        
        let stackView = UIStackView(arrangedSubviews: [
            self.redProgress,
            self.greenProgress,
            self.blueProgress])
        
        stackView.distribution = .fillEqually
        stackView.axis = .vertical
        
        return stackView
    }()
    
    lazy var bottomStackView: UIStackView =
    {
        [unowned self] in

        let stackView = UIStackView(arrangedSubviews: [
            self.histogramView,
            self.swatch,
            self.progressStackView])
        
        stackView.distribution = .fill
        stackView.axis = .horizontal
        stackView.alignment = .fill
        
        return stackView
    }()
    
    let redProgress = UIProgressView(progressViewStyle: .default)
    let greenProgress = UIProgressView(progressViewStyle: .default)
    let blueProgress = UIProgressView(progressViewStyle: .default)
    
    let shapeLayer = CAShapeLayer()

    var sampleRect = CGRect(x: 200,
        y: 200,
        width: 240,
        height: 240)
    
    let ciContext = CIContext()
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    let totalBytes = 4 // Bytes requires to hold 1x1 image returned from Area Average filter
    let bitmap = calloc(4, MemoryLayout<UInt8>.size)!

    override func viewDidLoad()
    {
        super.viewDidLoad()
   
        view.addSubview(mainStackView)
        
        redProgress.tintColor = UIColor.red
        greenProgress.tintColor = UIColor.green
        blueProgress.tintColor = UIColor.blue
        
        mainImageView.layer.addSublayer(shapeLayer)
        
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.lineWidth = 4
        
        shapeLayer.shadowColor = UIColor.white.cgColor
        shapeLayer.shadowOffset = CGSize(width: 0, height: 0)
        shapeLayer.shadowOpacity = 1
        shapeLayer.shadowRadius = 3
        
        mainImageView.image = UIImage(ciImage: engineImage)
        update()
    }

    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let touch = touches.first  else
        {
            return
        }
        
        let touchLocation = touch.location(in: mainImageView)
        
        let nearestCorner = sampleRect.corners.reduce(CGPoint(x: -1, y: -1))
        {
            $1.distanceTo(point: touchLocation) < $0.distanceTo(point: touchLocation) && $1.distanceTo(point: touchLocation) < 50 ? $1 : $0
        }
        
        if let touchedCorderIndex = sampleRect.corners.firstIndex(of: nearestCorner)
        {
            sampleRect.setCornerAtIndex(index: touchedCorderIndex,
                position: touchLocation)
            
            update()
        }
    }

    func update()
    {
        drawSampleRect()
        
        let sampleExtent = CIVector(cgRect: sampleRect.upsideDown(boundsHeight: imageSide))
        
        updateColorInformation(sampleExtent: sampleExtent)
        
        updateHistogram(sampleExtent: sampleExtent)
    }
    
    /// Draws a rectangle over the main image representing the sample area
    func drawSampleRect()
    {
        let bezierCurve = UIBezierPath(rect: sampleRect)
        
        for corner in sampleRect.corners
        {
            let handleRect = CGRect(x: corner.x,
                y: corner.y,
                width: 8,
                height: 8).offsetBy(dx: -4, dy: -4)
            
            let handle = UIBezierPath(ovalIn: handleRect)
            
            bezierCurve.append(handle)
        }
        
        shapeLayer.path = bezierCurve.cgPath
    }
    
    /// Updates the color swatch and RGB progress bars
    func updateColorInformation(sampleExtent: CIVector)
    {
        let averageImageFilter = CIFilter(name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: engineImage,
                kCIInputExtentKey: sampleExtent])!

        let averageImage = averageImageFilter.outputImage!

        ciContext.render(averageImage,
            toBitmap: bitmap,
            rowBytes: totalBytes,
            bounds: averageImage.extent,
            format: CIFormat.RGBA8,
            colorSpace: colorSpace)
        
        let rgba = UnsafeBufferPointer<UInt8>(
            start: UnsafePointer<UInt8>(bitmap.assumingMemoryBound(to: UInt8.self)),
            count: totalBytes)

        let red = Float(rgba[0]) / 255
        let green = Float(rgba[1]) / 255
        let blue = Float(rgba[2]) / 255
        
        redProgress.progress = red
        greenProgress.progress = green
        blueProgress.progress = blue
        
        swatch.backgroundColor = UIColor(red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: 1)
    }
    
    /// Updates the histogram
    func updateHistogram(sampleExtent: CIVector)
    {
        let histogramImage = engineImage
            .applyingFilter("CIAreaHistogram",
                            parameters: [
                    kCIInputExtentKey: sampleExtent,
                    kCIInputScaleKey: 15,
                    "inputCount" : 100])
            .applyingFilter("CIHistogramDisplayFilter",
                            parameters: [
                    "inputHeight": widgetsHeight])
        
        histogramView.image = histogramImage
    }
    
    override func viewDidLayoutSubviews()
    {
        mainStackView.frame = view.bounds.insetBy(dx: 0, dy: widgetsHeight)

        mainImageView.widthAnchor.constraint(equalToConstant: imageSide).isActive = true
        mainImageView.heightAnchor.constraint(equalToConstant: imageSide).isActive = true
        
        bottomStackView.heightAnchor.constraint(equalToConstant: widgetsHeight).isActive = true
        bottomStackView.widthAnchor.constraint(equalToConstant: imageSide).isActive = true
        
        histogramView.widthAnchor.constraint(equalToConstant: widgetsHeight).isActive = true
        swatch.widthAnchor.constraint(equalToConstant: widgetsHeight).isActive = true

        progressStackView.spacing = 10
        bottomStackView.spacing = 10
    }


}

// MARK extensions

extension CGPoint
{
    func distanceTo(point: CGPoint) -> CGFloat
    {
        return hypot(self.x - point.x, self.y - point.y)
    }
}

extension CGRect
{
    /// Vertically flip a rect
    func upsideDown(boundsHeight: CGFloat) -> CGRect
    {
        return CGRect(x: self.origin.x,
            y: boundsHeight - self.origin.y,
            width: self.width,
            height: 0 - self.height)
    }
    
    /// Return corners in order of top left, top right, bottom left, bottom right
    var corners: [CGPoint]
    {
        return [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: maxX, y: maxY)
        ]
    }
    
    /// Sets corner position at given index based on `corners`
    mutating func setCornerAtIndex(index: Int, position: CGPoint)
    {
        switch index
        {
        case 0:
            size.width = size.width + (origin.x - position.x)
            size.height = size.height + (origin.y - position.y)
            
            origin.x = position.x
            origin.y = position.y
            
        case 1:
            size.width = position.x - origin.x
            size.height = size.height + (origin.y - position.y)
            
            origin.y = position.y
            
        case 2:
            size.width = size.width + (origin.x - position.x)
            size.height = position.y - origin.y
            
            origin.x = position.x
            
        case 3:
            size.width = position.x - origin.x
            size.height = position.y - origin.y
            
        default:
            break
        }
    }
}

