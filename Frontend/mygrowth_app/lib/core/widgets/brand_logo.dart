import 'package:flutter/material.dart';

/// MyGrowth logo used across the app's branding surfaces.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'MyGrowth logo',
    );
  }
}
