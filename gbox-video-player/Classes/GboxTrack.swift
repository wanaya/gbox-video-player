//
//  GboxTrack.swift
//  Gbox
//
//  Created by Guillermo Anaya on 9/17/15.
//  Copyright © 2015 Gbox. All rights reserved.
//

import UIKit

public protocol Tackable {
  var title: String { get }
  var streamURL: NSURL { get }
}

extension Tackable {
  public var title: String { return "" }
  public var isPlayedToEnd: Bool { return false }
}

public class GboxTrack: NSObject {
  
  let url: NSURL
  let videoTitle: String
  
  public init(url: NSURL, title: String) {
    self.url = url
    self.videoTitle = title
  }
  
}

extension GboxTrack: Tackable {
  public var streamURL: NSURL { return url }
  public var title: String { return videoTitle }
}
