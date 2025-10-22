import UIKit
import Flutter
import GoogleMaps   

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Inicializa el SDK de Google Maps con tu API Key
    GMSServices.provideAPIKey("AIzaSyCcYjVE_wGd9ir5-9kl81E5puvjf-mST5s")

    // Registra los plugins de Flutter (incluyendo google_maps_flutter, etc.)
    GeneratedPluginRegistrant.register(with: self)

    // Llama al método del padre (debe ir al final)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
