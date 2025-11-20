import 'package:flutter/material.dart';

class FallbackImage extends StatefulWidget {
  final List<String> imageUrls;
  final String? placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const FallbackImage({
    Key? key,
    required this.imageUrls,
    this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<FallbackImage> createState() => _FallbackImageState();
}

class _FallbackImageState extends State<FallbackImage> {
  int _currentUrlIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() {
    if (_currentUrlIndex >= widget.imageUrls.length) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
  }

  void _onImageError() {
    if (mounted) {
      setState(() {
        _currentUrlIndex++;
        _isLoading = false;
      });
      
      // Try next URL after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _loadImage();
        }
      });
    }
  }

  void _onImageLoaded() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading && _currentUrlIndex < widget.imageUrls.length) {
      return _buildLoadingWidget();
    }

    if (_currentUrlIndex >= widget.imageUrls.length) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    return Image.network(
      widget.imageUrls[_currentUrlIndex],
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          _onImageLoaded();
          return child;
        }
        return _buildLoadingWidget();
      },
      errorBuilder: (context, error, stackTrace) {
        _onImageError();
        return _buildLoadingWidget();
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.router,
        size: widget.height != null ? widget.height! * 0.5 : 40,
        color: Colors.grey[600],
      ),
    );
  }
}

