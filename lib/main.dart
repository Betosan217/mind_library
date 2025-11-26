import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/book_provider.dart';
import 'providers/note_provider.dart';
import 'providers/reader_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/task/task_detail_screen.dart';
import 'models/task_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializar servicio de notificaciones
  await NotificationService().initialize();

  // Pedir permisos de notificaciones
  final granted = await NotificationService().requestPermissions();
  if (granted) {}

  // Configurar orientación
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _listenToNotificationTaps();
  }

  void _listenToNotificationTaps() {
    // Cuando app está abierta o en background
    NotificationService.notificationTapStream.stream.listen((taskId) {
      _navigateToTask(taskId);
    });

    // Cuando app estaba CERRADA
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Esperar a que la app termine de cargar
      await Future.delayed(const Duration(milliseconds: 1000));

      // Verificar si la app se abrió por una notificación
      final NotificationAppLaunchDetails? notificationAppLaunchDetails =
          await NotificationService().getNotificationAppLaunchDetails();

      if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
        final String? taskId =
            notificationAppLaunchDetails!.notificationResponse?.payload;

        if (taskId != null) {
          _navigateToTask(taskId);
        }
      }
    });
  }

  void _navigateToTask(String taskId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }

      final taskProvider = context.read<TaskProvider>();

      TaskModel? task;
      String? taskGroupId;

      for (var groupId in taskProvider.taskGroups.map((g) => g.id)) {
        final tasks = taskProvider.getTasksForGroup(groupId);
        try {
          final foundTask = tasks.firstWhere((t) => t.id == taskId);
          task = foundTask;
          taskGroupId = groupId;
          break;
        } catch (e) {
          continue;
        }
      }

      if (task != null && taskGroupId != null && context.mounted) {
        final taskGroup = taskProvider.taskGroups.firstWhere(
          (g) => g.id == taskGroupId,
        );

        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(taskGroup: taskGroup),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al navegar a tarea: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FolderProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ReaderProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          if (themeProvider.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: const SplashScreen(),
            );
          }

          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Wolib',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashWrapper(),
          );
        },
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
          // Inicializar streams solo UNA VEZ
          if (!_streamsInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && authProvider.user != null) {
                // Inicializar stream de carpetas
                context.read<FolderProvider>().initFoldersStream();

                // Inicializar stream de libros
                context.read<BookProvider>().initBooksStream(
                  authProvider.user!.uid,
                );

                setState(() {
                  _streamsInitialized = true;
                });
              }
            });
          }

          return const HomeScreen();
        } else {
          // Si el usuario cierra sesión, detener streams
          if (_streamsInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<FolderProvider>().stopFoldersStream();
                context.read<BookProvider>().stopBooksStream();

                NotificationService().cancelAllNotifications();

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
