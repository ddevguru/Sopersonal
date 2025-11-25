
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Logger {
  static Future<void> logToFile(String message) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/playsmart_log.txt');
      
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] $message\n';
      
      await file.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }
}