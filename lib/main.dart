import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc_client/app.dart';

import 'http_override.dart';

void main() {
  HttpOverrides.global = DeviceHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}
