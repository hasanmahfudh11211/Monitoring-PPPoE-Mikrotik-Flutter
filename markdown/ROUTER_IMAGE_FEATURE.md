# 🖼️ Router Image Feature

## Overview
Fitur ini menampilkan gambar router resmi dari Mikrotik berdasarkan model router yang terdeteksi. Gambar akan ditampilkan di bagian atas halaman System Resource.

## ✨ Features

### 1. **Multiple Fallback URLs**
- Setiap router memiliki multiple URL fallback untuk memastikan gambar bisa dimuat
- Jika URL pertama gagal, sistem akan otomatis mencoba URL berikutnya
- Fallback URLs dari berbagai sumber:
  - `https://i.mt.lv/cdn/rb/` (Primary)
  - `https://help.mikrotik.com/docs/static/img/` (Secondary)
  - `https://wiki.mikrotik.com/images/thumb/` (Tertiary)

### 2. **Smart Router Detection**
- Otomatis mendeteksi model router dari `board-name`
- Support untuk berbagai seri router Mikrotik:
  - **CCR Series**: CCR1009, CCR1016, CCR1036, CCR1072, CCR2004, CCR2116, CCR2216
  - **RB Series**: RB750, RB750r2, RB750Gr3, RB760iGS, RB850Gx2, RB951Ui, RB952Ui, RB960PGS, RB962UiGS, RB1100AHx2, RB1100AHx4, RB1200, RB2011UiAS, RB3011UiAS, RB4011iGS, RB450Gx4, RB5009UG, RB5009UPr, RB5011UPr, RB52G, RB53G, RB750UP, RB951G
  - **CHR Series**: Cloud Hosted Router

### 3. **FallbackImage Widget**
- Widget khusus untuk menangani multiple URLs
- Loading indicator saat gambar dimuat
- Error handling dengan fallback ke icon router
- Otomatis retry dengan URL berikutnya jika gagal

### 4. **Beautiful UI Design**
- Gambar ditampilkan dalam card dengan shadow dan rounded corners
- Overlay dengan nama router di bagian bawah
- Gradient overlay untuk readability
- Responsive design untuk berbagai ukuran layar

## 🛠️ Technical Implementation

### Files Created/Modified:

1. **`lib/services/router_image_service.dart`**
   - Service untuk mapping router models ke image URLs
   - Multiple fallback URLs untuk setiap router
   - Smart detection dan partial matching

2. **`lib/widgets/fallback_image.dart`**
   - Widget untuk menangani multiple image URLs
   - Loading states dan error handling
   - Automatic retry mechanism

3. **`lib/screens/system_resource_screen.dart`**
   - Updated untuk menampilkan router image
   - Integration dengan FallbackImage widget
   - Beautiful UI layout

### Key Methods:

```dart
// Get multiple fallback URLs for a router
List<String> getRouterImageUrls(String? boardName)

// Get primary URL (first in the list)
String getRouterImageUrl(String? boardName)

// Get clean display name
String getRouterDisplayName(String? boardName)

// Check if router has image support
bool hasRouterImage(String? boardName)
```

## 🎯 Usage

### Automatic Detection
Router image akan otomatis ditampilkan berdasarkan `board-name` yang didapat dari Mikrotik API:

```dart
// Example: CCR2116-1G-4S+ akan otomatis menampilkan gambar CCR2116
final imageUrls = RouterImageService.getRouterImageUrls('CCR2116-1G-4S+');
```

### Manual Usage
```dart
FallbackImage(
  imageUrls: ['url1', 'url2', 'url3'],
  fit: BoxFit.contain,
  width: 200,
  height: 200,
  errorWidget: Icon(Icons.router),
)
```

## 🔧 Configuration

### Adding New Router Models
Untuk menambahkan router model baru, edit `lib/services/router_image_service.dart`:

```dart
'NEW_ROUTER_MODEL': [
  'https://i.mt.lv/cdn/rb/new-router.png',
  'https://help.mikrotik.com/docs/static/img/new-router.png',
  'https://wiki.mikrotik.com/images/thumb/new-router.png'
],
```

### Custom Error Widget
```dart
FallbackImage(
  imageUrls: urls,
  errorWidget: Container(
    child: Icon(Icons.router, size: 80),
    color: Colors.grey[200],
  ),
)
```

## 🚀 Benefits

1. **Professional Look**: Menampilkan gambar router resmi memberikan tampilan yang lebih profesional
2. **User Experience**: User bisa langsung melihat model router yang sedang digunakan
3. **Reliability**: Multiple fallback URLs memastikan gambar selalu bisa dimuat
4. **Performance**: Smart loading dengan retry mechanism
5. **Maintainability**: Easy to add new router models

## 📱 Screenshots

Gambar router akan ditampilkan di bagian atas halaman System Resource dengan:
- Large card dengan shadow
- Router image di center
- Router name overlay di bottom
- Loading indicator saat dimuat
- Fallback icon jika semua URL gagal

## 🔮 Future Enhancements

1. **Caching**: Implement image caching untuk performance
2. **Offline Support**: Download dan cache images untuk offline use
3. **More Sources**: Tambah lebih banyak sumber gambar
4. **Custom Images**: Support untuk custom router images
5. **Animation**: Smooth transitions saat gambar dimuat

---

**Status**: ✅ **IMPLEMENTED & WORKING**
**Last Updated**: January 2025
**Version**: 1.0.0



































