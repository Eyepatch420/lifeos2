import 'package:local_auth/local_auth.dart';

/// Real biometric / device-credential authentication for the app lock and the
/// document vault (replaces the fake "Unlock" dialog).
class AuthService {
  const AuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// True if the device can actually prompt for biometrics or a PIN.
  static Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user. Returns true only on a successful authentication.
  ///
  /// If the device has no biometric/PIN configured we return true rather than
  /// locking the user out of their own data permanently.
  static Future<bool> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return true;
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
