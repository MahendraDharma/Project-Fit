// ProjectFit <-> the ProjectFit Bridge watch app (garmin-bridge/), over
// Garmin's Connect IQ Mobile SDK. Garmin Connect keeps its own link to the
// watch; this rides beside it, the way Garmin designed companion apps to.
//
// Channel `projectfit/connectiq`:
//   Dart -> here: selectDevices, devices, appStatus, pull {since}, openApp
//   here -> Dart: devicesChanged, message {device, data}
//
// The chosen watches are kept (NSSecureCoding) so Garmin Connect is opened
// only when the person picks again; the SDK's own advice.
import ConnectIQ
import Flutter
import Foundation

public final class ConnectIQBridge: NSObject, IQDeviceEventDelegate, IQAppMessageDelegate {
  public static let shared = ConnectIQBridge()

  /// The return URL scheme Garmin Connect opens us with. Also in Info.plist.
  public static let urlScheme = "projectfit-ciq"

  /// ProjectFit Bridge's application id (garmin-bridge/manifest.xml).
  static let appId = UUID(uuidString: "91df5607-cc03-4b40-8caf-988e21936190")!
  private static let devicesKey = "connectiq_devices"

  private var channel: FlutterMethodChannel?
  private var started = false
  private var devices: [IQDevice] = []

  public static func register(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "projectfit/connectiq", binaryMessenger: messenger)
    shared.channel = ch
    ch.setMethodCallHandler { call, result in shared.handle(call, result) }
    shared.start()
  }

  private func start() {
    if started { return }
    started = true
    ConnectIQ.sharedInstance().initialize(withUrlScheme: ConnectIQBridge.urlScheme,
                                          uiOverrideDelegate: nil)
    devices = loadDevices()
    for d in devices { listen(d) }
  }

  /// Garmin Connect came back with the watches the person shared.
  @discardableResult
  public func handle(url: URL) -> Bool {
    guard url.scheme == ConnectIQBridge.urlScheme else { return false }
    start()
    guard let parsed = ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url)
            as? [IQDevice] else { return false }
    ConnectIQ.sharedInstance().unregisterForAllDeviceEvents(self)
    ConnectIQ.sharedInstance().unregisterForAllAppMessages(self)
    devices = parsed
    saveDevices(parsed)
    for d in parsed { listen(d) }
    send("devicesChanged", nil)
    return true
  }

  private func listen(_ d: IQDevice) {
    ConnectIQ.sharedInstance().registerForDeviceEvents(d, delegate: self)
    ConnectIQ.sharedInstance().registerForAppMessages(app(d), delegate: self)
  }

  private func app(_ d: IQDevice) -> IQApp {
    IQApp(uuid: ConnectIQBridge.appId, store: ConnectIQBridge.appId, device: d)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    start()
    switch call.method {
    case "selectDevices":
      ConnectIQ.sharedInstance().showDeviceSelection()
      result(nil)
    case "devices":
      result(devices.map(describe))
    case "appStatus":
      guard let d = devices.first else { result(nil); return }
      ConnectIQ.sharedInstance().getAppStatus(app(d)) { status in
        DispatchQueue.main.async {
          guard let s = status else { result(nil); return }
          result(["installed": s.isInstalled, "version": Int(s.version)])
        }
      }
    case "pull":
      let args = call.arguments as? [String: Any]
      let since = (args?["since"] as? NSNumber)?.intValue ?? 0
      sendAll(["cmd": "pull", "since": since], result)
    case "openApp":
      guard let d = devices.first else { result("no_device"); return }
      ConnectIQ.sharedInstance().openAppRequest(app(d)) { r in
        DispatchQueue.main.async { result(ConnectIQBridge.name(r)) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Send [msg] to the app on every chosen watch; answers with the first
  /// watch's outcome ("success", "device_not_available", ...).
  private func sendAll(_ msg: [String: Any], _ result: @escaping FlutterResult) {
    guard !devices.isEmpty else { result("no_device"); return }
    var answered = false
    for d in devices {
      ConnectIQ.sharedInstance().sendMessage(msg, to: app(d), progress: nil) { r in
        DispatchQueue.main.async {
          if !answered {
            answered = true
            result(ConnectIQBridge.name(r))
          }
        }
      }
    }
  }

  private func describe(_ d: IQDevice) -> [String: Any] {
    let status = ConnectIQ.sharedInstance().getDeviceStatus(d)
    return [
      "uuid": d.uuid.uuidString,
      "name": d.friendlyName ?? "",
      "model": d.modelName ?? "",
      "connected": status.rawValue == 4, // IQDeviceStatus_Connected
    ]
  }

  // MARK: - IQDeviceEventDelegate / IQAppMessageDelegate

  public func deviceStatusChanged(_ device: IQDevice!, status: IQDeviceStatus) {
    send("devicesChanged", nil)
  }

  public func receivedMessage(_ message: Any!, from app: IQApp!) {
    send("message", ["device": app?.device?.uuid.uuidString ?? "", "data": message ?? NSNull()])
  }

  private func send(_ method: String, _ args: Any?) {
    DispatchQueue.main.async { self.channel?.invokeMethod(method, arguments: args) }
  }

  // MARK: - Persistence

  private func saveDevices(_ ds: [IQDevice]) {
    if let data = try? NSKeyedArchiver.archivedData(withRootObject: ds, requiringSecureCoding: true) {
      UserDefaults.standard.set(data, forKey: ConnectIQBridge.devicesKey)
    }
  }

  private func loadDevices() -> [IQDevice] {
    guard let data = UserDefaults.standard.data(forKey: ConnectIQBridge.devicesKey),
          let ds = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: IQDevice.self, from: data)
    else { return [] }
    return ds
  }

  /// By raw value, in IQConstants.h's order.
  static func name(_ r: IQSendMessageResult) -> String {
    let names = ["success", "unknown", "internal_error", "device_not_available",
                 "app_not_found", "device_busy", "unsupported_type", "insufficient_memory",
                 "timeout", "max_retries", "prompt_not_displayed", "app_already_running"]
    let i = Int(r.rawValue)
    return i >= 0 && i < names.count ? names[i] : "failed"
  }
}
