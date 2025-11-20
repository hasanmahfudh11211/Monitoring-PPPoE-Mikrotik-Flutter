import 'dart:convert';
import 'package:flutter/services.dart';

void main() async {
  print('=== TESTING JSON LOADING ===');
  
  try {
    // Test 1: Load JSON asset
    print('1. Loading JSON asset...');
    final String jsonString = await rootBundle.loadString('assets/router_images_online.json');
    print('   JSON string length: ${jsonString.length}');
    
    // Test 2: Parse JSON
    print('2. Parsing JSON...');
    final Map<String, dynamic> data = json.decode(jsonString);
    print('   Total items: ${data.length}');
    
    // Test 3: Check specific key
    print('3. Checking for CCR2116-12G-4S+...');
    if (data.containsKey('CCR2116-12G-4S+')) {
      final url = data['CCR2116-12G-4S+'];
      print('   ✅ FOUND: $url');
    } else {
      print('   ❌ NOT FOUND');
    }
    
    // Test 4: Show first 5 keys
    print('4. First 5 keys:');
    final keys = data.keys.take(5).toList();
    for (int i = 0; i < keys.length; i++) {
      print('   ${i + 1}. ${keys[i]}');
    }
    
    // Test 5: Check if URL is accessible
    print('5. Testing URL accessibility...');
    const testUrl = 'https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png';
    print('   Test URL: $testUrl');
    
    print('=== TEST COMPLETED ===');
    
  } catch (e) {
    print('❌ ERROR: $e');
  }
}



































