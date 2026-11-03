import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'matbaa/matbaa_app.dart';

/// Matbaa masaüstü uygulaması: `flutter run -d macos -t lib/main_matbaa.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MatbaaApp());
}
