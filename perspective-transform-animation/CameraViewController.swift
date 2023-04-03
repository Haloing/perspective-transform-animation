//
//  CameraViewController.swift
//  perspective-transform-animation
//
//  Created by imh on 2023/4/3.
//

import UIKit
import Vision
import AVFoundation

import RxSwift
import RxCocoa
import Toast_Swift

import PerspectiveTransform

struct CameraImage {
    var originImage:UIImage
    var cutImage:UIImage?
    
    // 识别结果
    var rectangle:VNRectangleObservation?
    // 四个点
    var rect:CGRect = .zero
        
    init(_ originImage:UIImage, cutImage:UIImage? = nil, rectangle:VNRectangleObservation? = nil) {
        self.originImage = originImage
        self.cutImage = cutImage
        // 识别结果
        self.rectangle = rectangle
    }
}

class CameraViewController: UIViewController {

    // MARK: - lazy var
    lazy var session:AVCaptureSession = {
         let s = AVCaptureSession()
        s.sessionPreset = .photo
        return s
    }()
    
    // device
    internal var device:AVCaptureDevice?
    
    lazy var contentView:CameraContentView = {
        let iv = CameraContentView(frame: .zero)
        iv.frame = .zero
        iv.backgroundColor = .black
        return iv
    }()
    
    lazy var imageView:UIImageView = {
        let lv = UIImageView(frame: .zero)
        lv.contentMode = .scaleAspectFit
        lv.backgroundColor = .clear
        lv.isHidden = true
        return lv
    }()
    
    // 文档扫描提示
    lazy var descLabel:UILabel = {
        let l = UILabel(frame: .zero)
        l.textColor = .white
        l.font = .boldSystemFont(ofSize: 16)
        l.textAlignment = .center
        l.text = "将文稿放在取景框内"
        return l
    }()
    
    lazy var controlView:CameraControlView = {
        let iv = (Bundle.main.loadNibNamed("CameraControlView", owner: nil) as! [CameraControlView])[0]
        iv.frame = .zero
        iv.backgroundColor = .clear
        return iv
    }()
    
    private let disposeBag = DisposeBag()
    
    // 拍照
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var deviceInput: AVCaptureDeviceInput?
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // 绘制文档区域
    private lazy var drawingLayer:CAShapeLayer = {
        let l = CAShapeLayer()
        return l
    }()
    private var bezierPath:UIBezierPath?
    
    private(set) var isLock:Bool = false
    private(set) var pointCount:Int = 30
    
    // 停止检测
    private(set) var isStopDetection:Bool = false
    
    
    // 存储检测到的坐标点
    private var topLeftPoints:[CGPoint] = []
    
    // 拍摄的图片
    private var images:[CameraImage] = []
    
    // 是否自动拍照
    internal var isAutomatic:Bool = true
        
    // MARK: - left cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.backButtonTitle = " "
        
        let appearnce = UINavigationBarAppearance()
        appearnce.configureWithOpaqueBackground()
        appearnce.backgroundColor = .clear
        appearnce.titleTextAttributes = [.foregroundColor: UIColor.red]
        
        /*-------去掉黑线------*/
        appearnce.shadowImage = UIImage()
        appearnce.shadowColor = .clear
        /*-------去掉黑线------*/
        
        navigationItem.standardAppearance = appearnce
        navigationItem.scrollEdgeAppearance = appearnce
                
        // 相机授权
        checkAuthorization()
        
        // 内容
        view.addSubview(contentView)
        // 控制
        view.addSubview(controlView)
        // 提示
        view.addSubview(descLabel)
        
        // 框
        view.layer.addSublayer(drawingLayer)
        
        // 显示截取的图片
        view.addSubview(imageView)
        
        // 手动拍照
        controlView.takePhotoBtn
            .rx.tap.subscribe(onNext: { [weak self] in
                self?.takePictureMethod()
            }).disposed(by: self.disposeBag)
        
        // 拍摄完成
        controlView.completeBtn.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.takeComplete()
            }).disposed(by: self.disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        contentView.frame = self.view.bounds
        controlView.frame = self.view.bounds
        drawingLayer.frame = self.view.bounds
        descLabel.frame = CGRect(x: 0, y: self.view.bounds.height - 140 - self.view.safeAreaInsets.bottom, width: self.view.bounds.width, height: 40)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard self.session.isRunning == false else {
            return
        }
        self.session.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.session.stopRunning()
    }
    
    // MARK: - event response
    private func takeComplete() {
        
    }
    
    // MARK: - public methods
    
    // MARK: - private methods
    private func takePictureMethod() {
        self.isLock = true
        var setting = AVCapturePhotoSettings()
        if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            setting = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        }
        self.photoOutput.capturePhoto(with: setting, delegate: self)
    }
    
    private func setupConfiguration() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("---------初始化device失败\n")
            return
        }
        self.device = device
        
        do {
            // 修改帧率
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20)
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
            device.unlockForConfiguration()
        } catch {
            print("------lockForConfiguration：\(error.localizedDescription)")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            deviceInput = input
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            let connection = videoOutput.connection(with: .video)
            connection?.videoOrientation = .portrait
            
            videoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            photoOutput.connections.last?.videoOrientation = .portrait
            contentView.previewLayer.session = session
            
            // 开启录制
            self.session.startRunning()
        } catch {
            print("------setupConfiguration：\(error.localizedDescription)")
        }
    }
    
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 用户同意使用摄像头
            self.setupConfiguration()
            break
            
        case .notDetermined:
            // 首次请求使用摄像头
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupConfiguration()
                    } else {
                        // 用户拒绝摄像头申请
                        self?.showAuthorizationAlert()
                    }
                }
            }
            break
            
        case .denied:
            // 用户拒绝摄像头申请
            self.showAuthorizationAlert()
            break
            
        case .restricted:
            // 用户无法开启摄像头
            self.showAuthorizationAlert()
            break
            
        default:
            break
        }
    }
    
    private func showAuthorizationAlert() {
        let alert = UIAlertController(title: "相机不可用", message: "请在iPhone的\"设置-拍试卷-相机\"选项中，开启使用相机", preferredStyle: .alert)
        let action = UIAlertAction(title: "去设置", style: .default) { [weak self] _ in
            self?.settingsCameraAuthorization()
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel) { _ in
            self.navigationController?.popViewController(animated: true)
        }
        alert.addAction(cancel)
        alert.addAction(action)
        self.present(alert, animated: true)
    }
    
    private func settingsCameraAuthorization() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - delegate
extension CameraViewController:AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let e = error {
            print("---------photoOutput error：\(e)\n")
            self.descLabel.text = "截取文稿出错"
            self.descLabel.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isLock = false
            }
        } else {
            guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data)?.normalized() else {
                print("---------fileDataRepresentation error：\n")
                self.descLabel.text = "截取文稿出错"
                self.descLabel.isHidden = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.isLock = false
                }
                return
            }
            
            // 截取成功
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.descLabel.text = nil
                self.descLabel.isHidden = true
            }
            print("---------photoOutput image：\(image)\n")
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            
            // 文稿截取
            self.bezierPath = nil
            self.drawingLayer.path = nil
            self.drawingLayer.setNeedsDisplay()
            
            self.topLeftPoints = []
            self.documentSegmentationHandler(image) { [weak self] pair, error in
                guard let self = self else { return }
                guard let p = pair else {
                    self.view.makeToast(error ?? "未检测到文档")
                    return
                }
                
                // 用于透视变换
                let pair1 = self.converPointImage(image, document: p.0)
                if let newImage = OpenCV.warpPerspective(image, tl: pair1.0, tr: pair1.1, bl: pair1.2, br: pair1.3) {
                    print("------生成图片 newImage：\(newImage)\n")
                    
                    // frame
                    let pair = self.rectanglePointConvert(image, rect: self.view.bounds, document: p.0)
                    let iw = newImage.size.width
                    let ih = newImage.size.height
                    
                    let maxW = self.view.bounds.width * 0.8
                    let maxH = min(self.view.bounds.height * 0.8, self.view.bounds.height - 200)
                    
                    var rect:CGRect
                    if (iw / maxW) > (ih / maxH) {
                        // 宽固定
                        let w = maxW
                        let h = w * ih / iw
                        rect = CGRect(x: (self.view.bounds.width - w) * 0.5, y: (self.view.bounds.height - h) * 0.5, width: w, height: h)
                    } else {
                        // 高固定
                        let h = maxH
                        let w = h * iw / ih
                        rect = CGRect(x: (self.view.bounds.width - w) * 0.5, y: (self.view.bounds.height - h) * 0.5, width: w, height: h)
                    }
                    self.imageView.isHidden = false
                    self.imageView.frame = rect
                    self.imageView.image = newImage
                                        
                    let start = Perspective(CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
                    let destination = Perspective(
                        CGPoint(x: pair.0.x - rect.origin.x, y: pair.0.y - rect.origin.y),
                        CGPoint(x: pair.1.x - rect.origin.x, y: pair.1.y - rect.origin.y),
                        CGPoint(x: pair.2.x - rect.origin.x, y: pair.2.y - rect.origin.y),
                        CGPoint(x: pair.3.x - rect.origin.x, y: pair.3.y - rect.origin.y)
                    )
                    
                    self.imageView.resetAnchorPoint()
                    self.imageView.layer.transform = start.projectiveTransform(destination: destination)
                                        
                    // 识别结果
                    let item = CameraImage(image, cutImage: newImage, rectangle: p.0)
                    self.images.append(item)
                    
                    UIView.animate(withDuration: 0.5) {
                        self.imageView.layer.transform = CATransform3DIdentity
                    } completion: { _ in
                        // 开启动画
                        self.genieAnimation()
                        
                        // 开始继续录制
                        self.isLock = false
                    }
                } else {
                    // 截取失败
                    self.view.makeToast("截取失败")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.isLock = false
                    }
                }
            }
        }
    }
    
    private func genieAnimation() {
        let rect = self.controlView.imageContentView.convert(self.controlView.imageView.frame, to: self.view)
        self.imageView.genieInTransition(withDuration: 0.5, destinationRect: rect, destinationEdge: .top) { [weak self] in
            guard let self = self else { return }
            self.controlView.imageView.image = self.images.last?.cutImage
            self.controlView.contentView.isHidden = self.images.count == 0
            self.controlView.countLabel.text = "\(self.images.count)"
            
            self.imageView.isHidden = true
            self.imageView.transform = .identity
        }
    }
    
    private func documentSegmentationHandler(_ image:UIImage, completionHandler: @escaping ((VNRectangleObservation, UIImage)?, String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            completionHandler(nil, "图片数据错误")
            return
        }
        let documentSegmentationRequest = VNDetectDocumentSegmentationRequest { request, error in
            guard let document = request.results?.first as? VNRectangleObservation else {
                completionHandler(nil, "未检测到文稿")
                return
            }
            completionHandler((document, image), nil)
        }
        
        let imageRequestHandler = VNImageRequestHandler(data: data, options: [:])
        do {
            try imageRequestHandler.perform([documentSegmentationRequest])
        } catch let error as NSError {
            print("Failed to perform image request: \(error)")
            completionHandler(nil, "文稿检测出错")
        }
    }
}

extension CameraViewController:AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 是否停止检测
        guard isStopDetection == false else {
            return
        }
        
        guard isLock == false else { return }
        isLock = true
    
        // 检测文档
        self.segmentationRequest(sampleBuffer) { pair, error in
            DispatchQueue.main.async {
                guard let p = pair else {
                    self.drawingLayer.path = nil
                    self.drawingLayer.setNeedsDisplay()
                    
                    self.descLabel.text = error ?? "未检测到文稿"
                    self.descLabel.isHidden = false
                    
                    self.isLock = false
                    return
                }
                
                // 检测到文档
                self.rectangleObservationHandler(p.0, image: p.1)
            }
        }
    }
    
    /// 处理检测结果
    /// - Parameter document: VNRectangleObservation
    /// - Parameter image: UIImage
    private func rectangleObservationHandler(_ document:VNRectangleObservation, image:UIImage) {
        // 检测到文档
        self.descLabel.text = self.isAutomatic ? "准备截取" : "点击拍照"
        self.descLabel.isHidden = false
        
        // 绘制文稿位置
        self.drawRectangleBorder(document, image: image)
        
        // 自动快门
        guard self.isAutomatic else {
            self.isLock = false
            self.topLeftPoints = []
            return
        }
        
        var list = self.topLeftPoints
        list.append(document.topLeft)
        if list.count < pointCount {
            self.topLeftPoints = list
            self.isLock = false
            
            self.descLabel.text = "保持稳定"
            self.descLabel.isHidden = false
            
        } else {
            // 截取后40项
            let slice = list[list.endIndex-pointCount..<list.endIndex]
            self.topLeftPoints = Array(slice)
            
            // 计算离散系数
            let discreteCoefficient = self.varianceStability(self.topLeftPoints)
            if discreteCoefficient.x < 0.15 && discreteCoefficient.y < 0.15 {
                // 拍照
                self.descLabel.text = "截取中..."
                self.descLabel.isHidden = false
                
                 self.takePictureMethod()
            } else {
                self.isLock = false
            }
        }
    }
    
    private func drawRectangleBorder(_ document:VNRectangleObservation, image:UIImage) {
        let pair = rectanglePointConvert(image, rect: self.drawingLayer.bounds, document: document)
        let topLeft = pair.0
        let topRight = pair.1
        let bottomLeft = pair.2
        let bottomRight = pair.3
        
        // 检测到文档
        self.bezierPath = UIBezierPath()
        self.bezierPath?.move(to: topLeft)
        self.bezierPath?.addLine(to: topRight)
        self.bezierPath?.addLine(to: bottomRight)
        self.bezierPath?.addLine(to: bottomLeft)
        self.bezierPath?.close()

        self.bezierPath?.lineWidth = 2
        self.bezierPath?.lineJoinStyle = .bevel
        self.bezierPath?.lineCapStyle = .butt
        
        self.drawingLayer.path = self.bezierPath?.cgPath
        self.drawingLayer.lineWidth = 2
        self.drawingLayer.strokeColor = 0xb83a63.color.withAlphaComponent(1.0).cgColor
        self.drawingLayer.fillColor = 0xb83a63.color.withAlphaComponent(0.2).cgColor
        self.drawingLayer.setNeedsDisplay()
    }
                
    private func segmentationRequest(_ sampleBuffer: CMSampleBuffer, completionHandler: @escaping ((VNRectangleObservation, UIImage)?, String?) -> Void) {
        // pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            completionHandler(nil, nil)
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let image = UIImage(ciImage: ciImage)
        
        let documentSegmentationRequest = VNDetectDocumentSegmentationRequest { request, error in
            guard let document = request.results?.first as? VNRectangleObservation, document.confidence > 0.9 else {
                completionHandler(nil, "未检测到文稿")
                return
            }
            completionHandler((document, image), nil)
        }
        let imageRequestHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, options: [:])
        do {
            try imageRequestHandler.perform([documentSegmentationRequest])
        } catch let error as NSError {
            print("Failed to perform image request: \(error)")
            completionHandler(nil, "文稿检测出错")
        }
    }
}

extension CameraViewController {
    /// 将角点转换到图片上
    /// - Parameters:
    ///   - image: 图片
    ///   - document: 文档对象
    /// - Returns: 四个角
    public func converPointImage(_ image:UIImage, document:VNRectangleObservation) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let topLeft = document.topLeft
        let topRight = document.topRight
        let bottomLeft = document.bottomLeft
        let bottomRight = document.bottomRight
        
        let tl = document.confidence > 0.8 ? CGPoint(x: topLeft.x * imageWidth, y: (1 - topLeft.y) * imageHeight) : CGPoint(x: 0, y: 0)
        let tr = document.confidence > 0.8 ? CGPoint(x: topRight.x * imageWidth, y: (1 - topRight.y) * imageHeight) : CGPoint(x: imageWidth, y: 0)
        let bl = document.confidence > 0.8 ? CGPoint(x: bottomLeft.x * imageWidth, y: (1 - bottomLeft.y) * imageHeight) : CGPoint(x: 0, y: imageHeight)
        let br = document.confidence > 0.8 ? CGPoint(x: bottomRight.x * imageWidth, y: (1 - bottomRight.y) * imageHeight) : CGPoint(x: imageWidth, y: imageHeight)
        return (tl, tr, bl, br)
    }
}

// 角点转到frame上
extension CameraViewController {
    /// 坐标转换
    /// - Parameters:
    ///   - image: 目标图片
    ///   - rect: 对应image view的frame
    ///   - document: 文档检测信息
    /// - Returns: 四个坐标点
    public func rectanglePointConvert(_ image:UIImage, rect:CGRect, document:VNRectangleObservation) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        var topLeft = document.topLeft
        var topRight = document.topRight
        var bottomLeft = document.bottomLeft
        var bottomRight = document.bottomRight
        
        // image view width & height
        let ivWidth = rect.size.width
        let ivHeight = rect.size.height
        
        if (imageWidth / ivWidth) > (imageHeight / ivHeight) {
            // 压缩宽度
            let width = ivWidth
            let height = imageHeight * width / imageWidth
            let offsetY = (ivHeight - height) * 0.5
            
            topLeft = document.confidence > 0.8 ? CGPoint(x: topLeft.x * width, y: offsetY + (1 - topLeft.y) * height) : CGPoint(x: 0, y: offsetY)
            topRight = document.confidence > 0.8 ? CGPoint(x: topRight.x * width, y: offsetY + (1 - topRight.y) * height) : CGPoint(x: width, y: offsetY)
            bottomLeft = document.confidence > 0.8 ? CGPoint(x: bottomLeft.x * width, y: offsetY + (1 - bottomLeft.y) * height) : CGPoint(x: 0, y: offsetY + height)
            bottomRight = document.confidence > 0.8 ? CGPoint(x: bottomRight.x * width, y: offsetY + (1 - bottomRight.y) * height) : CGPoint(x: width, y: offsetY + height)
        } else {
            // 压缩高度
            let height = ivHeight
            let width = imageWidth * height / imageHeight
            let offsetX = (ivWidth - width) * 0.5
            
            topLeft = document.confidence > 0.8 ? CGPoint(x: offsetX + topLeft.x * width, y: (1 - topLeft.y) * height) : CGPoint(x: offsetX, y: 0)
            topRight = document.confidence > 0.8 ? CGPoint(x: offsetX + topRight.x * width, y: (1 - topRight.y) * height) : CGPoint(x: offsetX + width, y: 0)
            bottomLeft = document.confidence > 0.8 ? CGPoint(x: offsetX + bottomLeft.x * width, y: (1 - bottomLeft.y) * height) : CGPoint(x: offsetX, y: height)
            bottomRight = document.confidence > 0.8 ? CGPoint(x: offsetX + bottomRight.x * width, y: (1 - bottomRight.y) * height) : CGPoint(x: offsetX + width, y: height)
        }
        return (topLeft, topRight, bottomLeft, bottomRight)
    }
}

extension CameraViewController {
    /// 检测文档的稳定性
    /// - Parameter list:坐标数据
    /// - Returns: 离散系数
    public func varianceStability(_ list:[CGPoint]) -> CGPoint {
        let x = list.map { p in
            p.x
        }
        let y = list.map { p in
            p.y
        }
        return CGPoint(x: discreteCoefficientMethod(x), y: discreteCoefficientMethod(y))
    }
    
    private func discreteCoefficientMethod(_ list:[CGFloat]) -> CGFloat {
        let count = list.count
        guard count > 10 else {
            return 1
        }
        let sum = list.reduce(0, { x, y in
            x + y
        })
        let averageValue = sum / CGFloat(count)
        let varianceSum = list.reduce(0, { x, y in
            (y - averageValue) * (y - averageValue) + x
        })
        // 方差
        let vari = varianceSum / CGFloat(count)
        // 标准方差
        let stVari = sqrt(vari)
        // 离散系数
        let discreteCoefficient = stVari / CGFloat(averageValue)
        return discreteCoefficient
    }
}


extension UIImage {
    func normalized() -> UIImage? {
        if imageOrientation == .up {
            return self
        }
        return repaintImage()
    }
    func repaintImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

extension Int {
    public var color:UIColor {
        let components = (
            R: Double((self >> 16) & 0xff) / 255,
            G: Double((self >> 08) & 0xff) / 255,
            B: Double((self >> 00) & 0xff) / 255
        )
        return UIColor(red: components.R, green: components.G, blue: components.B, alpha: 1.0)
    }
}


public extension UIView {
    func resetAnchorPoint() {
        let rect = frame
        layer.anchorPoint = CGPoint.zero
        frame = rect
    }
}
