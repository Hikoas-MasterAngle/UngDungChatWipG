import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;
  final IconData? fallbackIcon;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final trimmed = fallbackText.trim();
    final fallbackLetter =
        trimmed.isNotEmpty ? trimmed.substring(0, 1).toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.indigo,
      child: ClipOval(
        child: SizedBox.expand(
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallback(fallbackLetter);
                  },
                )
              : _buildFallback(fallbackLetter),
        ),
      ),
    );
  }

  Widget _buildFallback(String fallbackLetter) {
    if (fallbackIcon != null) {
      return Center(
        child: Icon(fallbackIcon, color: Colors.white, size: radius),
      );
    }

    return Center(
      child: Text(
        fallbackLetter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
