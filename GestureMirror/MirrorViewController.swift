//
//  MirrorViewController.swift
//  GestureMirror
//
//  Created by 中野湧仁 on 2019/07/18.
//  Copyright © 2019 中野湧仁. All rights reserved.
//


import UIKit
import AVFoundation

class MirrorViewController: UIViewController {
    
    // デバイスからの入力と出力を管理するオブジェクトの作成
    var captureSession = AVCaptureSession()
    // カメラデバイスそのものを管理するオブジェクトの作成
    // インカメの管理オブジェクトの作成
    var innerCamera: AVCaptureDevice?
    // キャプチャーの出力データを受け付けるオブジェクト
    var photoOutput : AVCapturePhotoOutput?
    // プレビュー表示用のレイヤ
    var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    
    var firstTouchPoint: CGPoint = .zero
    let maxZoomScale: CGFloat = 6.0
    let minZoomScale: CGFloat = 1.0
    let maxBrightScale: CGFloat = 1
    let minBrightScale: CGFloat = -1
    var oldZoomScale: CGFloat = 1.0
    var oldbrightnessScale: CGFloat = 1.0
    
    var isRunning = true
    var isReverse = true
    var isFirst = true
    
    lazy var zoomSlider: UISlider = {
        let v = UISlider(frame: CGRect(x:0, y:0, width:200, height:30))
//        v.layer.position = CGPoint(x:self.view.frame.midX, y:500)
        v.backgroundColor = UIColor.white
        v.layer.masksToBounds = true
        v.isHidden = true
        v.layer.cornerRadius = 10.0
        v.layer.shadowOpacity = 0.5
        v.minimumValue = 1
        v.maximumValue = 3
        v.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        v.addTarget(self, action: #selector(zoomSliderSwiped(slider:)), for: .valueChanged)
        view.addSubview(v)
        return v
    }()
    
    lazy var normalImageView: UIImageView = {
        let v = UIImageView(image: UIImage(named: "normal"))
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        return v
    }()
    
    lazy var reverseImageView: UIImageView = {
        let v = UIImageView(image: UIImage(named: "reverse"))
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        return v
    }()
    
    lazy var stopImageView: UIImageView = {
        let v = UIImageView(image: UIImage(named: "stop"))
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        return v
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
        setupPreviewLayer()
        setupInputOutput()
        singleTapConfig()
        doubleTapConfig()
        makeConstraints()
        startCapture()
        portlateSwipeGestureConfig()
        
        reverseImageView.isHidden = true
        stopImageView.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpSliderInitialValue()
    }

    func makeConstraints() {
        
//        zoomSlider.widthAnchor.constraint(equalToConstant: 100)
//        zoomSlider.heightAnchor.constraint(equalToConstant: 40)
//        zoomSlider.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
//        zoomSlider.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 100).isActive = true
        
        reverseImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        reverseImageView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 50).isActive = true
        
        normalImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        normalImageView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 50).isActive = true
        
        
        stopImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        stopImageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
    }
}

//MARK: AVCapturePhotoCaptureDelegateデリゲートメソッド
extension MirrorViewController: AVCapturePhotoCaptureDelegate{
    // 撮影した画像データが生成されたときに呼び出されるデリゲートメソッド
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation() {
            // Data型をUIImageオブジェクトに変換
            let uiImage = UIImage(data: imageData)
            // 写真ライブラリに画像を保存
            UIImageWriteToSavedPhotosAlbum(uiImage!, nil,nil,nil)
        }
    }
}

//MARK: カメラ設定メソッド
extension MirrorViewController{
    // カメラの画質の設定
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    
    // デバイスの設定
    func setupDevice() {
        // カメラデバイスのプロパティ設定
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        // プロパティの条件を満たしたカメラデバイスの取得
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.front {
                innerCamera = device
            }
        }
    }
    
    // 入出力データの設定
    func setupInputOutput() {
        do {
            guard let innerCamera = innerCamera else { return }
            // 指定したデバイスを使用するために入力を初期化
            let captureDeviceInput = try AVCaptureDeviceInput(device: innerCamera)
            // 指定した入力をセッションに追加
            captureSession.addInput(captureDeviceInput)
            // 出力データを受け取るオブジェクトの作成
            photoOutput = AVCapturePhotoOutput()
            // 出力ファイルのフォーマットを指定
            photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
        } catch {
            print(error)
        }
    }
    
    func startCapture() {
        guard !captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self ] in
            self?.captureSession.startRunning()
        }
    }
    
    // カメラのプレビューを表示するレイヤの設定
    func setupPreviewLayer() {
        // 指定したAVCaptureSessionでプレビューレイヤを初期化
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        // プレビューレイヤが、カメラのキャプチャーを縦横比を維持した状態で、表示するように設定
        self.cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // プレビューレイヤの表示の向きを設定
        self.cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        self.cameraPreviewLayer?.frame = view.frame
        self.view.layer.insertSublayer(self.cameraPreviewLayer!, at: 0)
    }
}


// Gesture設定
extension MirrorViewController {
    func setUpSliderInitialValue() {
        guard let zoomFactor = innerCamera?.videoZoomFactor else { return }
        zoomSlider.value = Float(zoomFactor)
    }
    @objc func zoomSliderSwiped(slider: UISlider){
        do {
            try innerCamera?.lockForConfiguration()
            print(slider.value)
            innerCamera?.videoZoomFactor = CGFloat(slider.value)
            innerCamera?.unlockForConfiguration()
        } catch let error as NSError {
            print(error)
        }
    }
    
    func portlateSwipeGestureConfig() {
        let portlateSwipeGesture = UIPanGestureRecognizer(target: self, action: #selector(portlateSwiped(_:)))
        portlateSwipeGesture.delegate = self
        view.addGestureRecognizer(portlateSwipeGesture)
    }
    
    @objc func portlateSwiped(_ gesture: UIPanGestureRecognizer) {
        guard isFirst else { return }
        isFirst.toggle()
        zoomSlider.isHidden = false
        let initialPoint = gesture.location(in: view)
        zoomSlider.layer.position = initialPoint
    }
    
    func singleTapConfig() {
        let singleTappGesture = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
        singleTappGesture.numberOfTapsRequired = 1
        singleTappGesture.delegate = self
        view.addGestureRecognizer(singleTappGesture)
    }
    
    // capturesessionではなく、別の方法を考えたい
    @objc func singleTapped() {
        if captureSession.isRunning {
            stopImageView.isHidden = false
            captureSession.stopRunning()
            isRunning = false
        } else {
            stopImageView.isHidden = true
            captureSession.startRunning()
            isRunning = true
        }
    }
    
    func doubleTapConfig() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        view.addGestureRecognizer(doubleTapGesture)
    }
    
    @objc func doubleTapped() {
        
        if isReverse {
            normalImageView.isHidden = true
            reverseImageView.isHidden = false
            cameraPreviewLayer?.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 1.0, 0.0)
            isReverse = false
        } else {
            normalImageView.isHidden = false
            reverseImageView.isHidden = true
            cameraPreviewLayer?.transform = CATransform3DIdentity
            isReverse = true
        }
    }
    
    }


extension MirrorViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
