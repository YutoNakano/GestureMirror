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
    let minBrightScale: CGFloat = 0
    var oldZoomScale: CGFloat = 1.0
    var oldbrightnessScale: CGFloat = 1.0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        captureSession.startRunning()
        portlateSwipeConfig()
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
    func portlateSwipeConfig() {
        let portlateSwipeGesture = UIPanGestureRecognizer(target: self, action: #selector(portlateSwiped(recognizer:)))
        view.addGestureRecognizer(portlateSwipeGesture)
    }
    
    @objc func portlateSwiped(recognizer: UIPanGestureRecognizer) {
    do {
        try innerCamera?.lockForConfiguration()
        let touchPoint = recognizer.location(in: view.window)
        var movementPortlate = (touchPoint.y - firstTouchPoint.y) / 50
        var movementLandscape = (touchPoint.x - firstTouchPoint.x) / 100
        guard let zoomFactor = innerCamera?.videoZoomFactor else { return }
        var currentZoomScale: CGFloat = zoomFactor
        
        let brightness = UIScreen.main.brightness
        var currentBrightness = brightness
        
        if movementPortlate < minZoomScale {
            movementPortlate = minZoomScale
        } else if movementPortlate > maxZoomScale {
            movementPortlate = maxZoomScale
        }
        
        if movementLandscape < minBrightScale {
            movementLandscape = minBrightScale
        } else if movementLandscape > maxBrightScale {
            movementLandscape = maxBrightScale
        }
        
        switch recognizer.state {
        case .began:
            firstTouchPoint = touchPoint
            print("タップスタート\(movementPortlate)")
        case .changed:
            currentZoomScale = movementPortlate
            currentBrightness = movementLandscape
            print("移動中\(movementPortlate)")
        case .cancelled, .ended:
            oldZoomScale = movementPortlate
            oldbrightnessScale = movementLandscape
            print("終了\(movementPortlate)")
        default: ()
        }
            innerCamera?.videoZoomFactor = currentZoomScale
            UIScreen.main.brightness = currentBrightness
            innerCamera?.unlockForConfiguration()
        } catch let error as NSError {
            print(error.description)
        }
    }
}
