import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_app/theme/app_theme.dart';

class PrimaryGradientButton extends StatefulWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    this.leading,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData? leading;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<PrimaryGradientButton> {
  double _scale = 1.0;

  void _animatePress(bool down) {
    setState(() => _scale = down ? 0.96 : 1.0);
  }

  Future<void> _handleTap() async {
    if (widget.onPressed == null || widget.isLoading) return;
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => _animatePress(true) : null,
      onTapCancel: enabled ? () => _animatePress(false) : null,
      onTapUp: enabled ? (_) => _animatePress(false) : null,
      onTap: enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: enabled
                ? AppGradients.primary
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.leading != null) ...[
                        Icon(widget.leading, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

