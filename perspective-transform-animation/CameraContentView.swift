//
//  CameraContentView.swift
//  perspective-transform-animation
//
//  Created by imh on 2023/4/3.
//

import UIKit
import AVFoundation

class CameraContentView: UIView {
    
    // 预览界面
    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let l = AVCaptureVideoPreviewLayer()
        l.videoGravity = .resizeAspect
        return l
    }()
    
    // 绘制文档区域
    private(set) lazy var drawingLayer:CAShapeLayer = {
        let l = CAShapeLayer()
        l.opacity = 0.5
        return l
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // 预览摄像头数据
        self.layer.addSublayer(previewLayer)
        // 添加标识layer
        self.layer.addSublayer(drawingLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
        drawingLayer.frame = self.bounds
    }
}
