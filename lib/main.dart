import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/book_provider.dart';
import 'providers/note_provider.dart';
import 'providers/reader_provider.dart'; // ✅ AGREGADO
import 'utils/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/splash_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configurar orientación
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FolderProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ReaderProvider()), // ✅ AGREGADO
        ChangeNotifierProvider(create: (_) => NoteProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mind Library',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const SplashWrapper(),
      ),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  void _initializeSplash() async {
    // Esperar el tiempo del splash
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Esperar a que el AuthProvider termine de verificar
    final authProvider = context.read<AuthProvider>();

    // Si todavía está cargando, esperar un poco más
    int attempts = 0;
    while (authProvider.isLoading && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      if (!mounted) return;
    }

    // Ocultar el splash
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }

    return const AuthWrapper();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _streamsInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Si está cargando, mostrar indicador
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si el usuario está autenticado
        if (authProvider.isAuthenticated) {
          // ✅ CORREGIDO: Inicializar streams solo UNA VEZ
          if (!_streamsInitialized) {
            // Usar addPostFrameCallback para asegurar que el context esté listo
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && authProvider.user != null) {
                debugPrint('🚀 Inicializando streams...');

                // Inicializar stream de carpetas
                context.read<FolderProvider>().initFoldersStream();

                // Inicializar stream de libros
                context.read<BookProvider>().initBooksStream(
                  authProvider.user!.uid,
                );

                setState(() {
                  _streamsInitialized = true;
                });

                debugPrint('✅ Streams inicializados correctamente');
              }
            });
          }

          return const HomeScreen();
        } else {
          // Si el usuario cierra sesión, detener streams
          if (_streamsInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                debugPrint('🛑 Deteniendo streams...');
                context.read<FolderProvider>().stopFoldersStream();
                context.read<BookProvider>().stopBooksStream();
                setState(() {
                  _streamsInitialized = false;
                });
              }
            });
          }

          return const LoginScreen();
        }
      },
    );
  }
}
