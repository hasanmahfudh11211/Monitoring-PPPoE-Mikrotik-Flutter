import 'dart:convert';
import 'package:flutter/services.dart';

class RouterImageServiceSimple {
  static Map<String, String>? _routerImages;
  
  // Load router images from JSON asset
  static Future<void> _loadRouterImages() async {
    if (_routerImages != null) return;
    
    try {
      print('RouterImageServiceSimple: Loading JSON asset...');
      final String jsonString = await rootBundle.loadString('assets/router_images_online.json');
      print('RouterImageServiceSimple: JSON string length: ${jsonString.length}');
      _routerImages = Map<String, String>.from(json.decode(jsonString));
      print('RouterImageServiceSimple: Loaded ${_routerImages!.length} router images');
      
      // Debug: Show first few keys
      final keys = _routerImages!.keys.take(5).toList();
      print('RouterImageServiceSimple: First 5 keys from JSON: $keys');
      
      // Debug: Check specific key
      if (_routerImages!.containsKey('CCR2116-12G-4S+')) {
        print('RouterImageServiceSimple: CCR2116-12G-4S+ found: ${_routerImages!['CCR2116-12G-4S+']}');
      } else {
        print('RouterImageServiceSimple: CCR2116-12G-4S+ NOT FOUND in JSON');
      }
    } catch (e) {
      print('RouterImageServiceSimple: Error loading router images: $e');
      _routerImages = {};
    }
  }

  /// Get router image URL for CCR2116-12G-4S+
  static Future<String> getCCR2116ImageUrl() async {
    await _loadRouterImages();
    
    // Direct lookup for CCR2116-12G-4S+
    const boardName = 'CCR2116-12G-4S+';
    
    if (_routerImages!.containsKey(boardName)) {
      final url = _routerImages![boardName]!;
      print('RouterImageServiceSimple: Found URL for $boardName: $url');
      return url;
    }
    
    print('RouterImageServiceSimple: No URL found for $boardName');
    return 'assets/mikrotik_product_images/default.png'; // Local default image
  }

  /// Get router image URL based on board name
  static Future<String> getRouterImageUrl(String? boardName) async {
    await _loadRouterImages();
    
    if (boardName == null || boardName.isEmpty) {
      return 'assets/mikrotik_product_images/default.png'; // Local default image
    }

    final cleanBoardName = boardName.trim();
    print('RouterImageServiceSimple: Looking for: "$cleanBoardName"');
    
    // Direct match
    if (_routerImages!.containsKey(cleanBoardName)) {
      final url = _routerImages![cleanBoardName]!;
      print('RouterImageServiceSimple: Direct match found: $url');
      return url;
    }

    // Show first few keys for debugging
    final keys = _routerImages!.keys.take(5).toList();
    print('RouterImageServiceSimple: First 5 keys: $keys');
    
    return 'assets/mikrotik_product_images/default.png'; // Local default image
  }
}