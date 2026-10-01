import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_app.dart';

/// Admin panel entry point (web):
///   flutter run -d chrome -t lib/admin/main_admin.dart --dart-define=API_URL=http://localhost:4000
///   flutter build web -t lib/admin/main_admin.dart --output build/admin --dart-define=API_URL=https://api.example.com
void main() => runApp(const ProviderScope(child: AdminApp()));
