import Cocoa
import AVFoundation
import CoreImage

class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Outlet for the view that displays the video
    @IBOutlet var videoView: NSView!

    // The preview layer displays the video from the camera
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    // The video session manages the input and output of the camera
    var videoSession: AVCaptureSession!

    // The photo output captures still images
    var photoOutput: AVCapturePhotoOutput!

    // Timer for capturing frames
    var faceDetectionTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the camera when the view loads
        setupCamera()

        // Set up the timer to capture a frame every second
        faceDetectionTimer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(captureFrame), userInfo: nil, repeats: true)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Start the video session when the view appears
        startSession()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        // Stop the video session when the view disappears
        stopSession()

        // Invalidate the timer when the view disappears
        faceDetectionTimer?.invalidate()
        faceDetectionTimer = nil
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // Update the preview layer's frame when the view's bounds change
        previewLayer.frame = videoView.bounds
    }

    func setupCamera() {
        // Create a new video session
        videoSession = AVCaptureSession()

        // Set the session preset to high quality
        videoSession.sessionPreset = .high

        // Enable layer-backed drawing for the video view
        videoView.wantsLayer = true

        // Get the default camera for video and create an input from it
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to access the camera.")
            return
        }

        // Add the input to the session if possible
        if videoSession.canAddInput(input) {
            videoSession.addInput(input)
        }

        // Create a new preview layer from the session and set its properties
        previewLayer = AVCaptureVideoPreviewLayer(session: videoSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = videoView.bounds

        // Add the preview layer as a sublayer of the video view's layer
        videoView.layer?.addSublayer(previewLayer)

        // Create a new photo output and set it as an output to the session
        photoOutput = AVCapturePhotoOutput()
        if videoSession.canAddOutput(photoOutput) {
            videoSession.addOutput(photoOutput)
        }
    }

    func startSession() {
        // Start the video session if it's not already running
        if !videoSession.isRunning {
            videoSession.startRunning()
        }
    }

    func stopSession() {
        // Stop the video session if it's running
        if videoSession.isRunning {
            videoSession.stopRunning()
        }
    }

    @objc func captureFrame() {
        // Capture a frame and perform face detection
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    // Add a property to store the face rectangle layer
    var faceRectangleLayer: CALayer?

    // ...

    func detectFaces(_ image: CIImage) {
        // Create a face detector
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

        // Perform face detection
        let features = faceDetector?.features(in: image)

        // Check if faces are detected
        if let faces = features as? [CIFaceFeature] {
            for face in faces {
                // Draw a square around the face
                drawFaceRectangle(face.bounds)

                // Remove the previous square after one second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.removeFaceRectangle()
                }

                print("Face detected at \(face.bounds)")
            }
        }
    }

    func drawFaceRectangle(_ bounds: CGRect) {
        // Remove previous face rectangle if exists
        removeFaceRectangle()

        // Increase the size of the rectangle by a certain factor (e.g., 1.5 times)
        let enlargementFactor: CGFloat = 1.5
        let enlargedBounds = bounds.insetBy(dx: -bounds.width * (enlargementFactor - 1) / 2, dy: -bounds.height * (enlargementFactor - 1) / 2)

        // Adjust the position of the rectangle (e.g., move it up and to the right)
        let xOffset: CGFloat = 60.0
        let yOffset: CGFloat = 100.0
        let adjustedBounds = CGRect(x: enlargedBounds.origin.x + xOffset, y: enlargedBounds.origin.y + yOffset, width: enlargedBounds.width, height: enlargedBounds.height)

        // Create a new layer for the enlarged and adjusted face rectangle
        let rectangleLayer = CALayer()
        rectangleLayer.borderColor = NSColor.green.cgColor
        rectangleLayer.borderWidth = 2.0
        rectangleLayer.frame = adjustedBounds

        // Add the layer to the preview layer
        previewLayer.addSublayer(rectangleLayer)

        // Store the layer in the property for later removal
        faceRectangleLayer = rectangleLayer
    }


    func removeFaceRectangle() {
        // Remove the previous face rectangle
        faceRectangleLayer?.removeFromSuperlayer()
        faceRectangleLayer = nil
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let image = CIImage(data: imageData) {
            detectFaces(image)
        }
    }
}
