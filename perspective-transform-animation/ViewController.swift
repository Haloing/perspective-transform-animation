//
//  ViewController.swift
//  perspective-transform-animation
//
//  Created by imh on 2023/4/3.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var cameraBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.cameraBtn.layer.cornerRadius = 20
        self.cameraBtn.layer.masksToBounds = true
        self.cameraBtn.layer.borderWidth = 1
        self.cameraBtn.layer.borderColor = 0xb83a63.color.cgColor
    }


    @IBAction func documentCaptureEvent(_ sender: Any) {
        let camera = CameraViewController()
        self.navigationController?.pushViewController(camera, animated: true)
    }
}

