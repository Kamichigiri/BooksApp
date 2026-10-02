import Flutter
import UIKit
import EpubViewerKit

// Locally patched for method results, event registration, and scene-aware presentation.
public class SwiftEpubViewerPlugin: NSObject, FlutterPlugin,FolioReaderPageDelegate,FlutterStreamHandler {
    
    let folioReader = FolioReader()
    static var pageResult: FlutterResult? = nil
    static var pageChannel:FlutterEventChannel? = nil
    
    var config: EpubConfig?
    
    
    //12.13
    public static func register(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(name: "vocsy_epub_viewer", binaryMessenger: registrar.messenger())
      let instance = SwiftEpubViewerPlugin()
        
      pageChannel = FlutterEventChannel.init(name: "page",
                                  binaryMessenger: registrar.messenger());
        pageChannel?.setStreamHandler(instance)
      
        registrar.addMethodCallDelegate(instance, channel: channel)
      }

      public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setConfig":
          guard let arguments = call.arguments as? [String: Any],
                let identifier = arguments["identifier"] as? String,
                let scrollDirection = arguments["scrollDirection"] as? String,
                let color = arguments["themeColor"] as? String,
                let allowSharing = arguments["allowSharing"] as? Bool,
                let enableTts = arguments["enableTts"] as? Bool,
                let nightMode = arguments["nightMode"] as? Bool else {
              result(FlutterError(
                  code: "invalid_configuration",
                  message: "Invalid EPUB reader configuration.",
                  details: nil
              ))
              return
          }

          self.config = EpubConfig(
              Identifier: identifier,
              tintColor: color,
              allowSharing: allowSharing,
              scrollDirection: scrollDirection,
              enableTts: enableTts,
              nightMode: nightMode
          )
          result(nil)
        case "setChannel":
          result(nil)
        case "open":
          guard let arguments = call.arguments as? [String: Any],
                let bookPath = arguments["bookPath"] as? String else {
              result(FlutterError(
                  code: "invalid_book_path",
                  message: "A local EPUB path is required.",
                  details: nil
              ))
              return
          }
          do {
              try self.open(epubPath: bookPath)
              result(nil)
          } catch let error as NSError {
              result(FlutterError(
                  code: "open_failed",
                  message: error.localizedDescription,
                  details: nil
              ))
          }
        case "close":
          self.close()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
    }

        public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            SwiftEpubViewerPlugin.pageResult = events
          return nil
      }

      public func onCancel(withArguments arguments: Any?) -> FlutterError? {
          SwiftEpubViewerPlugin.pageResult = nil
          return nil
      }
      
      
      private func open(epubPath: String) throws {
          guard !epubPath.isEmpty,
                FileManager.default.fileExists(atPath: epubPath) else {
              throw NSError(
                  domain: "vocsy_epub_viewer",
                  code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "The EPUB file does not exist."]
              )
          }
          guard let config = self.config?.config else {
              throw NSError(
                  domain: "vocsy_epub_viewer",
                  code: 2,
                  userInfo: [NSLocalizedDescriptionKey: "EPUB reader has not been configured."]
              )
          }
          guard let readerVc = activeViewController() else {
              throw NSError(
                  domain: "vocsy_epub_viewer",
                  code: 3,
                  userInfo: [NSLocalizedDescriptionKey: "No active application window is available."]
              )
          }

          folioReader.presentReader(
              parentViewController: readerVc,
              withEpubPath: epubPath,
              andConfig: config,
              shouldRemoveEpub: false
          )
          folioReader.readerCenter?.pageDelegate = self
      }

      private func activeViewController() -> UIViewController? {
          let rootViewController: UIViewController?
          if #available(iOS 13.0, *) {
              let activeScenes = UIApplication.shared.connectedScenes
                  .compactMap { $0 as? UIWindowScene }
                  .filter { $0.activationState == .foregroundActive }
              let activeWindows = activeScenes.flatMap { $0.windows }
              rootViewController = activeWindows
                  .first(where: { $0.isKeyWindow })?.rootViewController
                  ?? activeWindows.first(where: { !$0.isHidden })?.rootViewController
          } else if let appDelegate = UIApplication.shared.delegate {
              if let window = appDelegate.window {
                  rootViewController = window.rootViewController
              } else {
                  rootViewController = nil
              }
          } else {
              rootViewController = nil
          }

          var viewController = rootViewController
          while let presentedViewController = viewController?.presentedViewController {
              viewController = presentedViewController
          }
          return viewController
      }

      public func pageWillLoad(_ page: FolioReaderPage) {
          
          print("page.pageNumber:"+String(page.pageNumber))

          if (SwiftEpubViewerPlugin.pageResult != nil){
              SwiftEpubViewerPlugin.pageResult!(String(page.pageNumber))
          }

      }
      
      private func close(){
          folioReader.readerContainer?.dismiss(animated: true, completion: nil)
      }

  }
