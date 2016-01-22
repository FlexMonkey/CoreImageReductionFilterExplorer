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
        
        stackView.distribution = .EqualSpacing
        stackView.axis = .Vertical
        stackView.alignment = .Center
        
        return stackView
    }()
    
    lazy var progressStackView: UIStackView =
    {
        [unowned self] in
        
        let stackView = UIStackView(arrangedSubviews: [
            self.redProgress,
            self.greenProgress,
            self.blueProgress])
        
        stackView.distribution = .FillEqually
        stackView.axis = .Vertical
        
        return stackView
    }()
    
    lazy var bottomStackView: UIStackView =
    {
        [unowned self] in

        let stackView = UIStackView(arrangedSubviews: [
            self.histogramView,
            self.swatch,
            self.progressStackView])
        
        stackView.distribution = .Fill
        stackView.axis = .Horizontal
        stackView.alignment = .Fill
        
        return stackView
    }()
    
    let redProgress = UIProgressView(progressViewStyle: .Default)
    let greenProgress = UIProgressView(progressViewStyle: .Default)
    let blueProgress = UIProgressView(progressViewStyle: .Default)
    
    let shapeLayer = CAShapeLayer()

    var sampleRect = CGRect(x: 200,
        y: 200,
        width: 240,
        height: 240)
    
    let ciContext = CIContext()
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    let totalBytes = 4 // Bytes requires to hold 1x1 image returned from Area Average filter
    let bitmap = calloc(4, sizeof(UInt8))
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
   
        view.addSubview(mainStackView)
        
        redProgress.tintColor = UIColor.redColor()
        greenProgress.tintColor = UIColor.greenColor()
        blueProgress.tintColor = UIColor.blueColor()
        
        mainImageView.layer.addSublayer(shapeLayer)
        
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.blackColor().CGColor
        shapeLayer.lineWidth = 4
        
        shapeLayer.shadowColor = UIColor.whiteColor().CGColor
        shapeLayer.shadowOffset = CGSize(width: 0, height: 0)
        shapeLayer.shadowOpacity = 1
        shapeLayer.shadowRadius = 3
        
        mainImageView.image = UIImage(CIImage: engineImage)
        
        update()
    }

    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first  else
        {
            return
        }
        
        let touchLocation = touch.locationInView(mainImageView)
        
        let nearestCorner = sampleRect.corners.reduce(CGPoint(x: -1, y: -1))
        {
            $1.distanceTo(touchLocation) < $0.distanceTo(touchLocation) && $1.distanceTo(touchLocation) < 50 ? $1 : $0
        }
        
        if let touchedCorderIndex = sampleRect.corners.indexOf(nearestCorner)
        {
            sampleRect.setCornerAtIndex(touchedCorderIndex,
                position: touchLocation)
            
            update()
        }
    }

    func update()
    {
        drawSampleRect()
        
        let sampleExtent = CIVector(CGRect: sampleRect.upsideDown(640))
        
        updateColorInformation(sampleExtent)
        
        updateHistogram(sampleExtent)
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
            
            let handle = UIBezierPath(ovalInRect: handleRect)
            
            bezierCurve.appendPath(handle)
        }
        
        shapeLayer.path = bezierCurve.CGPath
    }
    
    /// Updates the color swatch and RGB progress bars
    func updateColorInformation(sampleExtent: CIVector)
    {
        let averageImageFilter = CIFilter(name: "CIAreaAverage",
            withInputParameters: [
                kCIInputImageKey: engineImage,
                kCIInputExtentKey: sampleExtent])!

        let averageImage = averageImageFilter.outputImage!

        ciContext.render(averageImage,
            toBitmap: bitmap,
            rowBytes: totalBytes,
            bounds: averageImage.extent,
            format: kCIFormatRGBA8,
            colorSpace: colorSpace)
        
        let bytes = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitmap),
            count: totalBytes)

        let rgba = UnsafeBufferPointer(start: bytes.baseAddress,
            count: bytes.count)

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
        let histogramImage = engineImage.imageByApplyingFilter("CIAreaHistogram", withInputParameters: [
                kCIInputExtentKey: sampleExtent,
                kCIInputScaleKey: 10,
                "inputCount" : 100])
            .imageByApplyingFilter("CIHistogramDisplayFilter", withInputParameters: nil)
        
        histogramView.image = histogramImage
    }
    
    override func viewDidLayoutSubviews()
    {
        mainStackView.frame = view.bounds.insetBy(dx: 0, dy: 100)

        mainImageView.widthAnchor.constraintEqualToConstant(640).active = true
        mainImageView.heightAnchor.constraintEqualToConstant(640).active = true
        
        bottomStackView.heightAnchor.constraintEqualToConstant(100).active = true
        bottomStackView.widthAnchor.constraintEqualToConstant(640).active = true
        
        histogramView.widthAnchor.constraintEqualToConstant(100).active = true
        swatch.widthAnchor.constraintEqualToConstant(100).active = true

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

