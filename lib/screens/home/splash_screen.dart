import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _letterControllers;
  late List<Animation<double>> _letterAnimations;
  final String text = 'Mind Library';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Crear un controlador para cada letra
    _letterControllers = List.generate(
      text.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      ),
    );

    // Crear animación de rebote para cada letra
    _letterAnimations = _letterControllers.map((controller) {
      return TweenSequence<double>([
        // Caída con rebote fuerte
        TweenSequenceItem(
          tween: Tween<double>(
            begin: -100.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.bounceOut)),
          weight: 100.0,
        ),
      ]).animate(controller);
    }).toList();

    // Iniciar animación de cada letra con delay progresivo
    for (int i = 0; i < text.length; i++) {
      Future.delayed(Duration(milliseconds: 100 * i), () {
        if (mounted) {
          _letterControllers[i].forward();
        }
      });
    }

    // Esperar 4 segundos y permitir que AuthWrapper maneje la navegación
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_navigated) {
        setState(() {
          _navigated = true;
        });
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _letterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si ya pasaron los 4 segundos, retornar un indicador temporal
    // AuthWrapper se encargará de la navegación
    if (_navigated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Logo de la app con animación Lottie
            Lottie.asset(
              'assets/animations/book.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 30),

            // Texto con animación de caída letra por letra
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(text.length, (index) {
                  return AnimatedBuilder(
                    animation: _letterAnimations[index],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _letterAnimations[index].value),
                        child: Text(
                          text[index],
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                            letterSpacing: text[index] == ' ' ? 8 : 1.2,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),

            const Spacer(flex: 1),

            // Animación de carga
            Lottie.asset(
              'assets/animations/blue_loading.json',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              repeat: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
