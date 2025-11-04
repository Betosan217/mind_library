// lib/widgets/common/animated_lottie_avatar.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Widget que muestra un avatar con animación Lottie
/// Se anima SOLO cuando se hace clic
class AnimatedLottieAvatar extends StatefulWidget {
  final String assetPath;
  final double size;
  final VoidCallback? onTap;
  final Widget? errorWidget;

  const AnimatedLottieAvatar({
    super.key,
    required this.assetPath,
    this.size = 32,
    this.onTap,
    this.errorWidget,
  });

  @override
  State<AnimatedLottieAvatar> createState() => _AnimatedLottieAvatarState();
}

class _AnimatedLottieAvatarState extends State<AnimatedLottieAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Crear el controller sin duración inicial
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAnimation() {
    if (_isLoaded && mounted) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _playAnimation();
        widget.onTap?.call();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          widget.assetPath,
          controller: _controller,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          repeat: false,
          onLoaded: (composition) {
            // Cuando se carga, configurar la duración del controller
            _controller.duration = composition.duration;
            setState(() {
              _isLoaded = true;
            });
          },
          errorBuilder: (context, error, stackTrace) {
            // Widget de error personalizado o por defecto
            return widget.errorWidget ??
                Icon(
                  Icons.person_rounded,
                  size: widget.size * 0.6,
                  color: Colors.grey[600],
                );
          },
        ),
      ),
    );
  }
}
