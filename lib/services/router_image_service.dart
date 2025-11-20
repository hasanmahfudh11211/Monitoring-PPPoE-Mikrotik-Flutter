import 'dart:convert';
import 'package:flutter/services.dart';

class RouterImageService {
  static Map<String, String>? _routerImages;
  
  // Load router images from JSON asset
  static Future<void> _loadRouterImages() async {
    if (_routerImages != null) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/router_images_online.json');
      _routerImages = Map<String, String>.from(json.decode(jsonString));
    } catch (e) {
      print('Error loading router images: $e');
      _routerImages = {};
    }
  }

  /// Get router image URLs based on board name (returns list of fallback URLs)
  static Future<List<String>> getRouterImageUrls(String? boardName) async {
    await _loadRouterImages();
    
    if (boardName == null || boardName.isEmpty) {
      print('RouterImageService: Board name is null or empty');
      return ['assets/mikrotik_product_images/default.png']; // Local default image
    }

    // Clean the board name (remove extra spaces, normalize)
    final cleanBoardName = boardName.trim();
    print('RouterImageService: Looking for board name: "$cleanBoardName"');
    print('RouterImageService: Total images loaded: ${_routerImages!.length}');
    
    // Direct match
    if (_routerImages!.containsKey(cleanBoardName)) {
      print('RouterImageService: Direct match found for "$cleanBoardName"');
      return [_routerImages![cleanBoardName]!];
    }

    // Partial match for variations
    for (final key in _routerImages!.keys) {
      if (cleanBoardName.contains(key)) {
        print('RouterImageService: Partial match found: "$key" for "$cleanBoardName"');
        return [_routerImages![key]!];
      }
    }

    // Try reverse partial match (key contains board name)
    for (final key in _routerImages!.keys) {
      if (key.contains(cleanBoardName)) {
        print('RouterImageService: Reverse partial match found: "$key" contains "$cleanBoardName"');
        return [_routerImages![key]!];
      }
    }

    print('RouterImageService: No match found for "$cleanBoardName", using default');
    // Return default if no match found
    return ['assets/mikrotik_product_images/default.png']; // Local default image
  }

  /// Get primary router image URL (first URL in the list)
  static Future<String> getRouterImageUrl(String? boardName) async {
    final urls = await getRouterImageUrls(boardName);
    return urls.isNotEmpty ? urls[0] : 'assets/mikrotik_product_images/default.png'; // Local default image
  }

  /// Get router display name (clean version)
  static String getRouterDisplayName(String? boardName) {
    if (boardName == null || boardName.isEmpty) {
      return 'Mikrotik Router';
    }
    return boardName.trim();
  }

  /// Check if router image is available
  static Future<bool> hasRouterImage(String? boardName) async {
    await _loadRouterImages();
    
    if (boardName == null || boardName.isEmpty) return false;
    
    final cleanBoardName = boardName.trim();
    return _routerImages!.containsKey(cleanBoardName) || 
           _routerImages!.keys.any((key) => cleanBoardName.contains(key));
  }
}