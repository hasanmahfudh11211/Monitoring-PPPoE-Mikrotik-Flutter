import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class GradientContainer extends StatelessWidget {
  final Widget child;

  const GradientContainer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF1A1A1A),  // Almost black
                  const Color(0xFF262626),  // Very dark gray
                  const Color(0xFF303030),  // Dark gray
                  const Color(0xFF262626),  // Very dark gray
                ]
              : const [
                  Color(0xFF2196F3),  // Material Blue
                  Color(0xFF64B5F6),  // Light Blue
                  Color(0xFFBBDEFB),  // Very Light Blue
                  Colors.white,
                ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ),
      ),
      child: child,
    );
  }
} 