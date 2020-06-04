//
//  PerformanceWrapper.swift
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/6/4.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

import Foundation
import GDPerformanceView_Swift

class PerformanceWrapper : NSObject {
    
    @objc
    public static func show() {
        PerformanceMonitor.shared().start()
    }
    
    @objc
    public static func hide() {
        PerformanceMonitor.shared().pause()
    }
}
