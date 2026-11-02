import 'package:flutter/material.dart';

class CardBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showBorder;
  final bool showShadow;

  const CardBox({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.borderRadius = 16,
    this.showBorder = true,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: margin ??
          EdgeInsets.only(
            bottom: screenHeight * 0.015,
          ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Material(
        color: backgroundColor ?? const Color(0xFF16483F),
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: double.infinity,
            padding: padding ??
                EdgeInsets.all(
                  screenWidth * 0.035,
                ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: showBorder
                  ? Border.all(
                color: Colors.white.withOpacity(0.08),
              )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
