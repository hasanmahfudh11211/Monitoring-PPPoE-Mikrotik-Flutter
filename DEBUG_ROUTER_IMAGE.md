# 🐛 Debug Router Image Issue

## Problem
Gambar router tidak muncul di System Resource screen, hanya menampilkan icon placeholder.

## Debug Steps

### 1. **Check JSON Loading**
- File `assets/router_images_online.json` harus ada di assets
- JSON harus valid dan bisa di-load
- Key `CCR2116-12G-4S+` harus ada di JSON

### 2. **Debug Console Output**
Jalankan aplikasi dan lihat console output untuk:

```
RouterImageServiceSimple: Loading JSON asset...
RouterImageServiceSimple: Loaded 264 router images
RouterImageServiceSimple: Looking for: "CCR2116-12G-4S+"
RouterImageServiceSimple: Direct match found: https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png
SystemResourceScreen: Loading image with URL: https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png
```

### 3. **Possible Issues**

#### Issue 1: JSON Asset Not Found
```
Error: Unable to load asset: assets/router_images_online.json
```
**Solution**: Pastikan file ada di `assets/` dan terdaftar di `pubspec.yaml`

#### Issue 2: JSON Parse Error
```
Error loading router images: FormatException: Unexpected character
```
**Solution**: Check JSON syntax, pastikan valid

#### Issue 3: Board Name Mismatch
```
RouterImageServiceSimple: No URL found for CCR2116-12G-4S+
```
**Solution**: Check exact board name dari Mikrotik API vs JSON key

#### Issue 4: Network Error
```
SystemResourceScreen: Error loading image: SocketException
```
**Solution**: Check internet connection, URL accessibility

### 4. **Manual Test**

#### Test JSON Loading:
```dart
// Add this to any screen for testing
Future<void> testJsonLoading() async {
  try {
    final String jsonString = await rootBundle.loadString('assets/router_images_online.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    print('JSON loaded: ${data.length} items');
    print('CCR2116-12G-4S+ exists: ${data.containsKey('CCR2116-12G-4S+')}');
    if (data.containsKey('CCR2116-12G-4S+')) {
      print('URL: ${data['CCR2116-12G-4S+']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### Test Direct URL:
```dart
// Test direct image loading
Image.network('https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png')
```

### 5. **Expected Behavior**

1. **Loading State**: Show "Loading image..." with spinner
2. **Success State**: Show actual router image
3. **Error State**: Show error icon with message
4. **Fallback State**: Show default router icon

### 6. **Console Output Analysis**

#### Success Case:
```
RouterImageServiceSimple: Loading JSON asset...
RouterImageServiceSimple: Loaded 264 router images
RouterImageServiceSimple: Looking for: "CCR2116-12G-4S+"
RouterImageServiceSimple: Direct match found: https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png
SystemResourceScreen: Loading image with URL: https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png
```

#### Error Case:
```
RouterImageServiceSimple: Error loading router images: [error details]
SystemResourceScreen: Error loading router image: [error details]
```

### 7. **Quick Fixes**

#### Fix 1: Force Refresh
```dart
// Add this to force reload
await RouterImageServiceSimple._loadRouterImages();
```

#### Fix 2: Direct URL Test
```dart
// Use direct URL for testing
const testUrl = 'https://cdn.mikrotik.com/web-assets/rb_images/2115_m.png';
```

#### Fix 3: Fallback Image
```dart
// Use local asset as fallback
Image.asset('assets/Mikrotik-logo.png')
```

## 🔧 Current Implementation

### Files Modified:
- `lib/services/router_image_service_simple.dart` - Simple service with debug
- `lib/screens/system_resource_screen.dart` - Updated with debug output
- `assets/router_images_online.json` - Router image mapping
- `pubspec.yaml` - Added JSON asset

### Debug Features Added:
- Console logging untuk setiap step
- Error handling dengan visual feedback
- Loading states dengan progress indicator
- Fallback states untuk error cases

## 🚀 Next Steps

1. **Run aplikasi** dan buka System Resource screen
2. **Check console output** untuk debug messages
3. **Identify issue** berdasarkan error messages
4. **Apply fix** sesuai dengan issue yang ditemukan

---

**Status**: 🔍 **DEBUGGING IN PROGRESS**
**Last Updated**: January 2025



































