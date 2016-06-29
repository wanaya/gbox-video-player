//
//  GboxSlider.swift
//  Gbox
//
//  Created by Guillermo Anaya on 9/21/15.
//  Copyright © 2015 Gbox. All rights reserved.
//

import UIKit

protocol SliderActions: class {
  func slideBeggin()
  func slideEnd()
  func dragging(sender: AnyObject)
}

class GboxSlider: UISlider {
  weak var delegate: SliderActions? = nil
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  
  required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    setup()
  }
  
  func setup() {
    self.addTarget(self, action: #selector(GboxSlider.dragStart), forControlEvents: .TouchDown)
    self.addTarget(self, action: #selector(GboxSlider.dragEnd), forControlEvents: [.TouchUpInside, .TouchUpOutside, .TouchCancel])
    self.addTarget(self, action: #selector(GboxSlider.dragging(_:)), forControlEvents: .ValueChanged)
    self.setMinimumTrackImage(UIImage.imageWithColor(UIColor.greenTeal()), forState: .Normal)
    self.setMaximumTrackImage(UIImage.imageWithColor(UIColor.steelGrey()), forState: .Normal)
    
    let image = UIImage(named: "icTimelineDragElement.png", inBundle: NSBundle(forClass: GboxSlider.self), compatibleWithTraitCollection: nil)
    setThumbImage(image, forState: .Normal)
    setThumbImage(image, forState: .Highlighted)
  }
  
  override func trackRectForBounds(bounds: CGRect) -> CGRect {
    let customBounds = CGRectMake(8, bounds.origin.y + 7, bounds.size.width, 5)
    super.trackRectForBounds(customBounds)
    return customBounds
  }
  
  func dragStart() {
    self.delegate?.slideBeggin()
  }
  
  func dragEnd() {
    self.delegate?.slideEnd()
  }
  
  func dragging(sender: AnyObject) {
    self.delegate?.dragging(sender)
  }
}

extension UIImage {
  static func imageWithColor(color: UIColor) -> UIImage {
    let rect = CGRectMake(0.0, 0.0, 1.0, 5.0)
    UIGraphicsBeginImageContext(rect.size);
    let context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    
    let image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image
  }
}

//colors
extension UIColor {
  static func greenTeal() -> UIColor {
    return UIColor(red: 13.0/255, green: 176.0/255, blue: 140.0/255, alpha: 1)
  }
  
  static func steelGrey() -> UIColor {
    return UIColor(red: 125.0/255, green: 139.0/255, blue: 142.0/255, alpha: 0.8)
  }
}
