import AVFoundation
import Flutter

public class FafaTorchPlugin: NSObject, FlutterPlugin, TorchHostApi {
  private let stateHandler = StateStreamHandler()
  private var eventChannel: StateChangesEventChannel?
  private var observedDevice: AVCaptureDevice?
  private var torchModeObservation: NSKeyValueObservation?
  private var torchAvailableObservation: NSKeyValueObservation?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FafaTorchPlugin()
    instance.stateHandler.plugin = instance
    TorchHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    instance.eventChannel = StateChangesStreamHandler.register(
      with: registrar.messenger(),
      streamHandler: instance.stateHandler
    )
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    TorchHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    stopObserving()
    stateHandler.sink = nil
    eventChannel?.setStreamHandler(nil)
    eventChannel = nil
  }

  func isAvailable() throws -> Bool {
    guard let device = resolveDevice() else { return false }
    return device.hasTorch && device.isTorchAvailable
  }

  func isOn() throws -> Bool {
    return resolveDevice()?.torchMode == .on
  }

  func supportsLevel() throws -> Bool {
    return resolveDevice()?.hasTorch == true
  }

  func level() throws -> Double {
    guard let device = resolveDevice(), device.hasTorch else {
      throw PigeonError(code: "torchUnavailable", message: "Torch is not available.", details: nil)
    }
    return Double(device.torchLevel)
  }

  func turnOn(level: Double?) throws {
    guard let device = resolveDevice(), device.hasTorch, device.isTorchAvailable else {
      throw PigeonError(code: "torchUnavailable", message: "Torch is not available.", details: nil)
    }
    guard level == nil || device.isTorchModeSupported(.on) else {
      throw PigeonError(
        code: "torchUnavailable", message: "Torch mode is not supported.", details: nil)
    }

    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      if let level = level {
        try applyLevel(device, value: level)
      } else {
        device.torchMode = .on
      }
    } catch {
      throw mapError(error)
    }

    emitState()
  }

  func turnOff() throws {
    guard let device = resolveDevice(), device.hasTorch else {
      throw PigeonError(code: "torchUnavailable", message: "Torch is not available.", details: nil)
    }

    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      device.torchMode = .off
    } catch {
      throw mapError(error)
    }

    emitState()
  }

  func currentState() -> TorchState {
    let device = resolveDevice()
    return TorchState(
      available: device?.hasTorch == true && device?.isTorchAvailable == true,
      on: device?.torchMode == .on
    )
  }

  func emitState() {
    stateHandler.emit(currentState())
  }

  func startObserving() {
    stopObserving()
    guard let device = resolveDevice(), device.hasTorch else { return }
    observedDevice = device
    torchModeObservation = device.observe(\.torchMode, options: [.new]) { [weak self] _, _ in
      self?.emitStateOnMain()
    }
    torchAvailableObservation = device.observe(\.isTorchAvailable, options: [.new]) {
      [weak self] _, _ in
      self?.emitStateOnMain()
    }
  }

  func stopObserving() {
    torchModeObservation?.invalidate()
    torchModeObservation = nil
    torchAvailableObservation?.invalidate()
    torchAvailableObservation = nil
    observedDevice = nil
  }

  private func applyLevel(_ device: AVCaptureDevice, value: Double) throws {
    let level: Float
    if value >= 1.0 {
      level = AVCaptureDevice.maxAvailableTorchLevel
    } else {
      level = Float(max(value, 0.01))
    }
    try device.setTorchModeOn(level: level)
  }

  private func resolveDevice() -> AVCaptureDevice? {
    if let device = AVCaptureDevice.default(
      .builtInWideAngleCamera, for: .video, position: .back),
      device.hasTorch
    {
      return device
    }
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInTelephotoCamera,
        .builtInDualCamera,
        .builtInDualWideCamera,
        .builtInTripleCamera,
      ],
      mediaType: .video,
      position: .back
    )
    return discovery.devices.first(where: { $0.hasTorch })
  }

  private func emitStateOnMain() {
    if Thread.isMainThread {
      emitState()
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.emitState()
      }
    }
  }

  private func mapError(_ error: Error) -> PigeonError {
    let nsError = error as NSError
    if nsError.domain == AVFoundationErrorDomain {
      switch nsError.code {
      case AVError.deviceInUseByAnotherApplication.rawValue:
        return PigeonError(
          code: "torchInUse", message: error.localizedDescription, details: nil)
      case AVError.torchLevelUnavailable.rawValue:
        return PigeonError(
          code: "torchUnavailable", message: error.localizedDescription, details: nil)
      default:
        break
      }
    }
    return PigeonError(
      code: "torchOperationFailed", message: error.localizedDescription, details: nil)
  }
}

private final class StateStreamHandler: StateChangesStreamHandler {
  weak var plugin: FafaTorchPlugin?
  var sink: PigeonEventSink<TorchState>?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<TorchState>) {
    self.sink = sink
    plugin?.startObserving()
    if let state = plugin?.currentState() {
      sink.success(state)
    }
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
    plugin?.stopObserving()
  }

  func emit(_ state: TorchState) {
    sink?.success(state)
  }
}
