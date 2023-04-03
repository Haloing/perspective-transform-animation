//
//  CameraControlView.swift
//  perspective-transform-animation
//
//  Created by imh on 2023/4/3.
//

import UIKit

class CameraControlView: UIView {

    @IBOutlet weak var takePhotoBtn: UIButton!
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    
    @IBOutlet weak var imageContentView: UIView!    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var completeBtn: UIButton!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // 设置拍照按钮
        let configuration = UIImage.SymbolConfiguration(pointSize: 70)
        let image = UIImage(systemName: "circle.inset.filled", withConfiguration: configuration)
        takePhotoBtn.setImage(image, for: .normal)
        takePhotoBtn.backgroundColor = .clear
        
        // 边框
        self.imageContentView.layer.cornerRadius = 4
        self.imageContentView.layer.masksToBounds = true
        self.imageContentView.layer.borderWidth = 1
        self.imageContentView.layer.borderColor = UIColor.white.cgColor
        
        // 数量
        self.countLabel.layer.cornerRadius = 10
        self.countLabel.layer.masksToBounds = true
    }

}
