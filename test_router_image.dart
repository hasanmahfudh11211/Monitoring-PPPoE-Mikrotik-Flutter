import 'dart:convert';
import 'package:flutter/services.dart';

void main() async {
  // Test loading JSON
  try {
    print('Testing JSON loading...');
    final String jsonString = await rootBundle.loadString('assets/router_images_online.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    print('JSON loaded successfully! Total items: ${data.length}');
    
    // Test specific router
    const boardName = 'CCR2116-12G-4S+';
    if (data.containsKey(boardName)) {
      print('Found $boardName: ${data[boardName]}');
    } else {
      print('NOT FOUND: $boardName');
      print('Available keys (first 10):');
      data.keys.take(10).forEach((key) => print('  - $key'));
    }
  } catch (e) {
    print('Error: $e');
  }
}



































