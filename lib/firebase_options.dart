// File generated for Firebase project meta-f5d71 (META)
// API keys are injected via --dart-define=FIREBASE_API_KEY=... or native google-services.json
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  static bool get hasConfiguredApiKey => _apiKey.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:712603916123:web:0f493f5aa1101a33ea6c7e',
    messagingSenderId: '712603916123',
    projectId: 'meta-f5d71',
    authDomain: 'meta-f5d71.firebaseapp.com',
    storageBucket: 'meta-f5d71.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:712603916123:android:20bce483a421342bea6c7e',
    messagingSenderId: '712603916123',
    projectId: 'meta-f5d71',
    storageBucket: 'meta-f5d71.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:712603916123:android:20bce483a421342bea6c7e',
    messagingSenderId: '712603916123',
    projectId: 'meta-f5d71',
    storageBucket: 'meta-f5d71.firebasestorage.app',
    iosBundleId: 'com.metaai.afetdestek.afetDestek',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:712603916123:android:20bce483a421342bea6c7e',
    messagingSenderId: '712603916123',
    projectId: 'meta-f5d71',
    storageBucket: 'meta-f5d71.firebasestorage.app',
    iosBundleId: 'com.metaai.afetdestek.afetDestek',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:712603916123:web:0f493f5aa1101a33ea6c7e',
    messagingSenderId: '712603916123',
    projectId: 'meta-f5d71',
    authDomain: 'meta-f5d71.firebaseapp.com',
    storageBucket: 'meta-f5d71.firebasestorage.app',
  );
}
