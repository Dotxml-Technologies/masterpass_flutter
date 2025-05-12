import Flutter
import UIKit
import MasterPassKit

public class SwiftMasterpassPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "masterpass", binaryMessenger: registrar.messenger())
        let instance = SwiftMasterpassPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "checkout" {
            guard let arguments = call.arguments as? [String: Any],
                  let code = arguments["code"] as? String,
                  let system = arguments["system"] as? String,
                  let key = arguments["key"] as? String,
                  let amountString = arguments["amount"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid parameters", details: nil))
                return
            }
            
            // Convert String to Double
            guard let amount = Double(amountString) else {
                result(FlutterError(code: "INVALID_AMOUNT", message: "Amount must be a valid number (e.g., '100.0')", details: nil))
                return
            }
            
            let masterpassSystem: MPSystem = (system == "Live") ? .live : .test
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.checkout(code: code, amount: amount, system: masterpassSystem, key: key, flutterResult: result)
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func checkout(code: String, amount: String, system: MPSystem, key: String, flutterResult: @escaping FlutterResult) {
        let masterpass = MPMasterPass()
        let masterpassDelegate = MasterpassDelegate(flutterResult: flutterResult)
        
        DispatchQueue.main.async {
            guard let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else {
                flutterResult(FlutterError(code: "NO_ROOT_VC", message: "Root view controller not found", details: nil))
                return
            }
            
            // ✅ Pass amount as Double
            masterpass.checkout(
                withCode: code,
                amount: amount, // Now a Double
                apiKey: key,
                system: system,
                controller: rootViewController,
                delegate: masterpassDelegate
            )
        }
    }
}

// MARK: - Masterpass Delegate
class MasterpassDelegate: UIViewController, MPMasterPassDelegate {
    private var flutterResult: FlutterResult
    
    init(flutterResult: @escaping FlutterResult) {
        self.flutterResult = flutterResult
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    func masterpassError(_ masterpassError: MPError) {
        let errorMessage: String
        switch masterpassError {
        case .MPErrorNetworkError:
            errorMessage = "NETWORK_ERROR"
        case .MPErrorPaymentError:
            errorMessage = "PAYMENT_ERROR"
        case .MPErrorOTPError:
            errorMessage = "OTP_ERROR"
        default:
            errorMessage = "UNKNOWN_ERROR (\(masterpassError.rawValue))"
        }
        
        let checkoutResult = CheckoutResult(code: errorMessage, reference: "Error code: \(masterpassError.rawValue)")
        sendResult(checkoutResult)
    }
    
    func masterpassPaymentSucceeded(withTransactionReference transactionReference: String!) {
        sendResult(CheckoutResult(code: "PAYMENT_SUCCEEDED", reference: transactionReference))
    }
    
    func masterpassPaymentFailed(withTransactionReference transactionReference: String!) {
        sendResult(CheckoutResult(code: "PAYMENT_FAILED", reference: transactionReference))
    }
    
    func masterpassUserDidCancel() {
        sendResult(CheckoutResult(code: "USER_CANCELLED", reference: "no_ref"))
    }
    
    private func sendResult(_ result: CheckoutResult) {
        DispatchQueue.main.async {
            self.flutterResult(result.dictionaryRepresentation)
        }
    }
}

// MARK: - Checkout Result Model
class CheckoutResult {
    var code: String
    var reference: String
    
    init(code: String, reference: String) {
        self.code = code
        self.reference = reference
    }
    
    var dictionaryRepresentation: [String: String] {
        return ["code": code, "reference": reference]
    }
}