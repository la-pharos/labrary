import UIKit
import Flutter
import FirebaseCore
import FirebaseAuth
import Vision

@main
@objc class AppDelegate:
  FlutterAppDelegate,
  FlutterImplicitEngineDelegate {

  private let textRecognitionChannelName =
    "com.la_pharos.labrary/text_recognition"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
      [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Firebase Phone Auth silent push
    application.registerForRemoteNotifications()

    return super.application(
      application,
      didFinishLaunchingWithOptions:
        launchOptions
    )
  }

  // =====================================================
  // Flutter Engine 초기화 후 플러그인 + OCR 채널 등록
  // =====================================================
  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    // sqflite 포함 Flutter 플러그인 등록
    GeneratedPluginRegistrant.register(
      with: engineBridge.pluginRegistry
    )

    // OCR MethodChannel 등록
    registerTextRecognitionChannel(
      binaryMessenger:
        engineBridge.applicationRegistrar.messenger()
    )
  }

  // =====================================================
  // OCR MethodChannel
  // =====================================================
  private func registerTextRecognitionChannel(
    binaryMessenger: FlutterBinaryMessenger
  ) {
    let channel = FlutterMethodChannel(
      name: textRecognitionChannelName,
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler {
      [weak self] call,
      result in

      guard let self = self else {
        result(
          FlutterError(
            code: "app_delegate_unavailable",
            message:
              "OCR 처리 객체를 찾지 못했습니다.",
            details: nil
          )
        )
        return
      }

      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments =
          call.arguments as? [String: Any],
        let imagePath =
          arguments["imagePath"] as? String,
        !imagePath
          .trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          .isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_image_path",
            message:
              "이미지 경로가 올바르지 않습니다.",
            details: nil
          )
        )
        return
      }

      let requestedLanguages =
        arguments["languages"] as? [String]
        ?? [
          "ko-KR",
          "en-US",
        ]

      self.recognizeText(
        imagePath: imagePath,
        requestedLanguages:
          requestedLanguages,
        flutterResult: result
      )
    }

    print(
      "✅ [OCR] MethodChannel 등록 완료"
    )
  }

  // =====================================================
  // Vision OCR
  // =====================================================
  private func recognizeText(
    imagePath: String,
    requestedLanguages: [String],
    flutterResult: @escaping FlutterResult
  ) {
    DispatchQueue.global(
      qos: .userInitiated
    ).async {
      autoreleasepool {
        let imageURL =
          URL(fileURLWithPath: imagePath)

        guard FileManager.default.fileExists(
          atPath: imageURL.path
        ) else {
          DispatchQueue.main.async {
            flutterResult(
              FlutterError(
                code: "image_not_found",
                message:
                  "이미지 파일을 찾을 수 없습니다.",
                details: imagePath
              )
            )
          }
          return
        }

        let request =
          VNRecognizeTextRequest {
            request,
            error in

            if let error = error {
              DispatchQueue.main.async {
                flutterResult(
                  FlutterError(
                    code:
                      "text_recognition_failed",
                    message:
                      "텍스트 인식에 실패했습니다.",
                    details:
                      error.localizedDescription
                  )
                )
              }
              return
            }

            guard let observations =
              request.results
                as? [
                  VNRecognizedTextObservation
                ]
            else {
              DispatchQueue.main.async {
                flutterResult("")
              }
              return
            }

            let recognizedLines =
              observations.compactMap {
                observation -> String? in

                observation
                  .topCandidates(1)
                  .first?
                  .string
              }

            let recognizedText =
              recognizedLines
                .joined(separator: "\n")
                .trimmingCharacters(
                  in: .whitespacesAndNewlines
                )

            DispatchQueue.main.async {
              flutterResult(
                recognizedText
              )
            }
          }

        request.recognitionLevel =
          .accurate

        request.usesLanguageCorrection =
          true

        request.recognitionLanguages =
          requestedLanguages

        if #available(iOS 16.0, *) {
          request.automaticallyDetectsLanguage =
            true
        }

        let requestHandler =
          VNImageRequestHandler(
            url: imageURL,
            options: [:]
          )

        do {
          try requestHandler.perform([
            request,
          ])
        } catch {
          DispatchQueue.main.async {
            flutterResult(
              FlutterError(
                code:
                  "image_processing_failed",
                message:
                  "이미지를 처리하지 못했습니다.",
                details:
                  error.localizedDescription
              )
            )
          }
        }
      }
    }
  }

  // =====================================================
  // Firebase Phone Auth silent push
  // =====================================================
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo:
      [AnyHashable: Any],
    fetchCompletionHandler completionHandler:
      @escaping (
        UIBackgroundFetchResult
      ) -> Void
  ) {
    if Auth.auth()
      .canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }

    super.application(
      application,
      didReceiveRemoteNotification:
        userInfo,
      fetchCompletionHandler:
        completionHandler
    )
  }
}