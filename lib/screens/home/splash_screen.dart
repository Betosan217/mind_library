import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _dotsController;

  late Animation<double> _piece1Animation;
  late Animation<double> _piece2Animation;
  late Animation<double> _piece3Animation;
  late Animation<Offset> _piece1Offset;
  late Animation<Offset> _piece2Offset;
  late Animation<Offset> _piece3Offset;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Controlador para la animación del logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Controlador para la animación del texto
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Controlador para los puntos de carga
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    // Animaciones de opacidad para cada pieza
    _piece1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _piece2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOut),
      ),
    );

    _piece3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
      ),
    );

    // Animaciones de posición para cada pieza (convergiendo hacia el centro)
    _piece1Offset =
        Tween<Offset>(
          begin: const Offset(-2.0, -2.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _logoController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _piece2Offset =
        Tween<Offset>(begin: const Offset(0.0, -3.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _logoController,
            curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    _piece3Offset =
        Tween<Offset>(begin: const Offset(2.0, -2.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _logoController,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    // Animación del texto
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _textSlide = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Iniciar animaciones
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _logoController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _textController.forward();
      }
    });

    // Navegar después de 3 segundos
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && !_navigated) {
        setState(() {
          _navigated = true;
        });
        // Aquí agregarías tu lógica de navegación
        // Navigator.pushReplacement(context, ...);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Si ya navegó, mostrar indicador temporal
    if (_navigated) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Logo animado con SVG
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pieza 1 (izquierda - clara)
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _piece1Offset.value * 50,
                        child: Opacity(
                          opacity: _piece1Animation.value,
                          child: CustomPaint(
                            size: const Size(140, 140),
                            painter: LogoPiece1Painter(
                              color: isDark
                                  ? AppColors.grey700
                                  : AppColors.grey300,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Pieza 2 (centro - media)
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _piece2Offset.value * 50,
                        child: Opacity(
                          opacity: _piece2Animation.value,
                          child: CustomPaint(
                            size: const Size(140, 140),
                            painter: LogoPiece2Painter(
                              color: AppColors.grey500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Pieza 3 (derecha - oscura)
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _piece3Offset.value * 50,
                        child: Opacity(
                          opacity: _piece3Animation.value,
                          child: CustomPaint(
                            size: const Size(140, 140),
                            painter: LogoPiece3Painter(
                              color: isDark
                                  ? AppColors.grey300
                                  : AppColors.grey800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Nombre de la app con animación
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: Opacity(
                    opacity: _textOpacity.value,
                    child: Text(
                      'Wolib',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Indicador de carga con 3 puntos animados
            AnimatedBuilder(
              animation: _dotsController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final value = (_dotsController.value - delay) % 1.0;
                    final scale = value < 0.5
                        ? 1.0 + (value * 2)
                        : 2.0 - (value * 2);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.scale(
                        scale: scale.clamp(0.5, 1.5),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.grey600
                                : AppColors.grey400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

// Custom Painters para cada pieza del logo
class LogoPiece1Painter extends CustomPainter {
  final Color color;

  LogoPiece1Painter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scale = size.width / 1024;

    // Pieza izquierda escalada
    path.moveTo(58 * scale, 415.02 * scale);
    path.lineTo(188.521 * scale, 282.609 * scale);
    path.cubicTo(
      207.906 * scale,
      262.943 * scale,
      239.563 * scale,
      262.715 * scale,
      259.229 * scale,
      282.1 * scale,
    );
    path.lineTo(346.386 * scale, 368.012 * scale);
    path.lineTo(215.865 * scale, 500.423 * scale);
    path.cubicTo(
      196.48 * scale,
      520.089 * scale,
      164.822 * scale,
      520.317 * scale,
      145.156 * scale,
      500.932 * scale,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LogoPiece2Painter extends CustomPainter {
  final Color color;

  LogoPiece2Painter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scale = size.width / 1024;

    // Pieza central escalada
    path.moveTo(223 * scale, 569.386 * scale);
    path.lineTo(492.867 * scale, 295.609 * scale);
    path.cubicTo(
      512.253 * scale,
      275.943 * scale,
      543.91 * scale,
      275.715 * scale,
      563.576 * scale,
      295.1 * scale,
    );
    path.lineTo(650.733 * scale, 381.012 * scale);
    path.lineTo(380.865 * scale, 654.789 * scale);
    path.cubicTo(
      361.48 * scale,
      674.455 * scale,
      329.822 * scale,
      674.683 * scale,
      310.156 * scale,
      655.298 * scale,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LogoPiece3Painter extends CustomPainter {
  final Color color;

  LogoPiece3Painter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scale = size.width / 1024;

    // Pieza derecha escalada
    path.moveTo(389 * scale, 729.567 * scale);
    path.lineTo(829.575 * scale, 282.609 * scale);
    path.cubicTo(
      848.961 * scale,
      262.943 * scale,
      880.618 * scale,
      262.715 * scale,
      900.284 * scale,
      282.1 * scale,
    );
    path.lineTo(987.441 * scale, 368.012 * scale);
    path.lineTo(546.865 * scale, 814.97 * scale);
    path.cubicTo(
      527.48 * scale,
      834.637 * scale,
      495.822 * scale,
      834.864 * scale,
      476.156 * scale,
      815.479 * scale,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
