import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VisionFace") {
      VisionFace.register(registrar.messenger())
    }
  }
}

/// On-device face detection with Apple Vision. Returns, per face, a box
/// normalized to the upright image with a top-left origin, head pose in
/// degrees, eye openness ratios from landmarks, and (for files) capture quality.
enum VisionFace {
  private static var frameOrientation: CGImagePropertyOrientation = .up

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "veil/vision", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      DispatchQueue.global(qos: .userInitiated).async {
        let reply: Any
        switch call.method {
        case "detectFile": reply = detectFile(args)
        case "detectFrame": reply = detectFrame(args)
        case "featurePrint": reply = featurePrint(args)
        default: reply = FlutterMethodNotImplemented
        }
        DispatchQueue.main.async { result(reply) }
      }
    }
  }

  private static func detectFile(_ args: [String: Any]) -> Any {
    guard let path = args["path"] as? String,
          let image = UIImage(contentsOfFile: path),
          let cg = image.cgImage else {
      return FlutterError(code: "bad_image", message: "Could not read image", details: nil)
    }
    let handler = VNImageRequestHandler(
      cgImage: cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
    return run(handler, withQuality: true) ?? []
  }

  private static func detectFrame(_ args: [String: Any]) -> Any {
    guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
          let width = args["width"] as? Int,
          let height = args["height"] as? Int,
          let bytesPerRow = args["bytesPerRow"] as? Int else {
      return FlutterError(code: "bad_frame", message: "Missing frame data", details: nil)
    }
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
    guard let pb = buffer else { return [] }
    CVPixelBufferLockBaseAddress(pb, [])
    let dst = CVPixelBufferGetBaseAddress(pb)!
    let dstStride = CVPixelBufferGetBytesPerRow(pb)
    data.withUnsafeBytes { src in
      for row in 0..<height {
        memcpy(dst + row * dstStride, src.baseAddress! + row * bytesPerRow, min(dstStride, bytesPerRow))
      }
    }
    CVPixelBufferUnlockBaseAddress(pb, [])

    // Camera frames may arrive rotated; remember whichever orientation finds a face.
    let candidates: [CGImagePropertyOrientation] =
      [frameOrientation] + [.up, .leftMirrored, .right, .left, .rightMirrored].filter { $0 != frameOrientation }
    for o in candidates {
      let faces = run(VNImageRequestHandler(cvPixelBuffer: pb, orientation: o), withQuality: false) ?? []
      if !faces.isEmpty {
        frameOrientation = o
        return faces
      }
    }
    return []
  }

  /// Generic Vision image descriptor of an already-cropped face. A built-in,
  /// download-free stand-in until a dedicated face model is bundled.
  private static func featurePrint(_ args: [String: Any]) -> Any {
    guard let data = (args["png"] as? FlutterStandardTypedData)?.data,
          let cg = UIImage(data: data)?.cgImage else {
      return FlutterError(code: "bad_image", message: "Could not read face crop", details: nil)
    }
    let request = VNGenerateImageFeaturePrintRequest()
    cpuOnInSimulator(request)
    do { try VNImageRequestHandler(cgImage: cg).perform([request]) } catch {
      return FlutterError(code: "vision", message: error.localizedDescription, details: nil)
    }
    guard let obs = request.results?.first else { return [Double]() }
    let n = obs.elementCount
    var out = [Double](repeating: 0, count: n)
    obs.data.withUnsafeBytes { raw in
      if obs.elementType == .float {
        let p = raw.bindMemory(to: Float.self)
        for i in 0..<n { out[i] = Double(p[i]) }
      } else {
        let p = raw.bindMemory(to: Double.self)
        for i in 0..<n { out[i] = p[i] }
      }
    }
    return out
  }

  /// The simulator has no Neural Engine; some Vision requests fail without this.
  private static func cpuOnInSimulator(_ request: VNRequest) {
    #if targetEnvironment(simulator)
    request.usesCPUOnly = true
    #endif
  }

  private static func run(_ handler: VNImageRequestHandler, withQuality: Bool) -> [[String: Any]]? {
    let landmarks = VNDetectFaceLandmarksRequest()
    landmarks.revision = VNDetectFaceLandmarksRequestRevision3
    var requests: [VNRequest] = [landmarks]
    let quality = VNDetectFaceCaptureQualityRequest()
    if withQuality { requests.append(quality) }
    requests.forEach(cpuOnInSimulator)
    do { try handler.perform(requests) } catch { return nil }

    let qualities = (quality.results ?? []).map { ($0.boundingBox, $0.faceCaptureQuality) }
    return (landmarks.results ?? []).map { face in
      let b = face.boundingBox
      var out: [String: Any] = [
        "x": b.minX, "y": 1 - b.maxY, "w": b.width, "h": b.height,
        "yaw": deg(face.yaw), "roll": deg(face.roll), "pitch": deg(face.pitch),
      ]
      if let l = face.landmarks?.leftEye { out["leftEye"] = openness(l) }
      if let r = face.landmarks?.rightEye { out["rightEye"] = openness(r) }
      if let q = qualities.min(by: { dist($0.0, b) < dist($1.0, b) })?.1 {
        out["quality"] = q
      }
      return out
    }
  }

  /// Eye height over eye width; drops sharply when the eye closes.
  private static func openness(_ region: VNFaceLandmarkRegion2D) -> Double {
    let pts = region.normalizedPoints
    guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
          let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max(),
          maxX > minX else { return 0 }
    return Double((maxY - minY) / (maxX - minX))
  }

  private static func deg(_ n: NSNumber?) -> Double { (n?.doubleValue ?? 0) * 180 / .pi }

  private static func dist(_ a: CGRect, _ b: CGRect) -> CGFloat {
    hypot(a.midX - b.midX, a.midY - b.midY)
  }
}

extension CGImagePropertyOrientation {
  init(_ o: UIImage.Orientation) {
    switch o {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
