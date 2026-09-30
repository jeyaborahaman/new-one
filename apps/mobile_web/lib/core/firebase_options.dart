import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Firebase client configuration for project "call-1c522".
/// These values identify the app to Google; they are not secrets (access is enforced by Firebase rules and
/// API-key restrictions). The service-account key used by the backend is the real secret and never lives here.
class JeyaboFirebase {
  static const webVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY'); // Firebase console > Cloud Messaging > Web Push certificates

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDugZRuGHcxqgq83LKMR9MdjbFj2ai2sNg',
    authDomain: 'call-1c522.firebaseapp.com',
    projectId: 'call-1c522',
    storageBucket: 'call-1c522.firebasestorage.app',
    messagingSenderId: '415271614284',
    appId: '1:415271614284:web:552e912fb079a3526f01e9',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyB3r6GkuaIrSXpYyzNWIdguT6OmbiWqEA8',
    projectId: 'call-1c522',
    storageBucket: 'call-1c522.firebasestorage.app',
    messagingSenderId: '415271614284',
    appId: '1:415271614284:android:4165dd40bfe51fa16f01e9',
  );

  /// null on platforms we have no Firebase app for yet (iOS needs GoogleService-Info.plist and an APNs key).
  static FirebaseOptions? get current {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    return null;
  }
}
