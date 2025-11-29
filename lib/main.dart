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

// 🔥 Variable global para guardar el taskId cuando la app está cerrada
String? _pendingNotificationTaskId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializar servicio de notificaciones
  await NotificationService().initialize();

  // 🆕 VERIFICAR SI LA APP SE ABRIÓ POR UNA NOTIFICACIÓN (APP CERRADA)
  final NotificationAppLaunchDetails? launchDetails =
      await NotificationService().getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    _pendingNotificationTaskId = launchDetails!.notificationResponse?.payload;
    debugPrint(
      '🔔 App abierta por notificación. TaskId: $_pendingNotificationTaskId',
    );
  }

  // Pedir permisos de notificaciones
  final granted = await NotificationService().requestPermissions();
  if (granted) {
    debugPrint('✅ Permisos de notificación concedidos');
  }

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
    // ✅ Para cuando la app está ABIERTA o en BACKGROUND
    NotificationService.notificationTapStream.stream.listen((taskId) {
      debugPrint('🔔 Notificación tocada (app abierta/background): $taskId');
      _navigateToTask(taskId);
    });
  }

  void _navigateToTask(String taskId) async {
    try {
      debugPrint('📍 Iniciando navegación a tarea: $taskId');

      // ⏳ Esperar a que el navigator esté disponible (máx 3 segundos)
      int attempts = 0;
      while (_navigatorKey.currentContext == null && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        debugPrint('❌ Context no disponible');
        return;
      }

      // ✅ Obtener providers ANTES de cualquier await
      final authProvider = context.read<AuthProvider>();
      final taskProvider = context.read<TaskProvider>();

      // ⏳ Esperar a que AuthProvider esté listo (máx 2 segundos)
      attempts = 0;
      while (authProvider.isLoading && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // ✅ Verificar mounted después del await
      if (!context.mounted) {
        debugPrint('❌ Context desmontado después de esperar AuthProvider');
        return;
      }

      if (!authProvider.isAuthenticated) {
        debugPrint('❌ Usuario no autenticado');
        return;
      }

      // ⏳ Esperar a que TaskProvider tenga datos (máx 2 segundos)
      attempts = 0;
      while (taskProvider.taskGroups.isEmpty && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // ✅ Verificar mounted después del await
      if (!context.mounted) {
        debugPrint('❌ Context desmontado después de esperar TaskProvider');
        return;
      }

      if (taskProvider.taskGroups.isEmpty) {
        debugPrint('❌ No hay grupos de tareas disponibles');
        return;
      }

      // 🔍 Buscar la tarea
      TaskModel? task;
      String? taskGroupId;

      for (var group in taskProvider.taskGroups) {
        final tasks = taskProvider.getTasksForGroup(group.id);
        try {
          final foundTask = tasks.firstWhere((t) => t.id == taskId);
          task = foundTask;
          taskGroupId = group.id;
          debugPrint('✅ Tarea encontrada en grupo: ${group.name}');
          break;
        } catch (e) {
          continue;
        }
      }

      // ✅ Verificar mounted antes de navegar
      if (task != null && taskGroupId != null && context.mounted) {
        final taskGroup = taskProvider.taskGroups.firstWhere(
          (g) => g.id == taskGroupId,
        );

        debugPrint('🚀 Navegando a TaskDetailScreen...');

        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(taskGroup: taskGroup),
          ),
        );

        debugPrint('✅ Navegación completada');
      } else {
        debugPrint('❌ Tarea no encontrada: $taskId');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error al navegar a tarea: $e');
      debugPrint('Stack: $stackTrace');
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
    // ⚡ Si hay notificación pendiente, acortar el splash a 1.5 segundos
    final splashDuration = _pendingNotificationTaskId != null
        ? const Duration(milliseconds: 1500)
        : const Duration(seconds: 3);

    await Future.delayed(splashDuration);

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // ⚡ Esperar máximo 1 segundo a que AuthProvider termine
    int attempts = 0;
    while (authProvider.isLoading && attempts < 10) {
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
  bool _hasHandledPendingNotification = false;

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

                // 🆕 PROCESAR NOTIFICACIÓN PENDIENTE (APP CERRADA)
                _handlePendingNotification();
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
                  _hasHandledPendingNotification = false;
                });
              }
            });
          }

          return const LoginScreen();
        }
      },
    );
  }

  // 🆕 MANEJAR LA NOTIFICACIÓN PENDIENTE (OPTIMIZADO)
  void _handlePendingNotification() async {
    if (_hasHandledPendingNotification || _pendingNotificationTaskId == null) {
      return;
    }

    _hasHandledPendingNotification = true;

    debugPrint(
      '🔔 Procesando notificación pendiente: $_pendingNotificationTaskId',
    );

    // ⚡ Esperar solo 500ms para que los streams se inicialicen
    await Future.delayed(const Duration(milliseconds: 500));

    // ✅ Verificar mounted después del await
    if (!mounted) {
      debugPrint('❌ Widget desmontado después de delay inicial');
      return;
    }

    // ✅ Obtener provider ANTES de cualquier otro await
    final taskProvider = context.read<TaskProvider>();

    // ⚡ Esperar máximo 1.5 segundos a que TaskProvider tenga datos
    int attempts = 0;
    while (taskProvider.taskGroups.isEmpty && attempts < 15) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // ✅ Verificar mounted después del await
    if (!mounted) {
      debugPrint('❌ Widget desmontado después de esperar TaskProvider');
      return;
    }

    if (taskProvider.taskGroups.isEmpty) {
      debugPrint('❌ TaskProvider sin datos después de esperar');
      _pendingNotificationTaskId = null;
      return;
    }

    debugPrint(
      '✅ TaskProvider listo con ${taskProvider.taskGroups.length} grupos',
    );

    // 🔍 Buscar la tarea
    TaskModel? task;
    String? taskGroupId;

    for (var group in taskProvider.taskGroups) {
      final tasks = taskProvider.getTasksForGroup(group.id);
      try {
        final foundTask = tasks.firstWhere(
          (t) => t.id == _pendingNotificationTaskId,
        );
        task = foundTask;
        taskGroupId = group.id;
        break;
      } catch (e) {
        continue;
      }
    }

    if (task != null && taskGroupId != null && mounted) {
      final taskGroup = taskProvider.taskGroups.firstWhere(
        (g) => g.id == taskGroupId,
      );

      debugPrint('🚀 Navegando a tarea desde notificación...');

      // ⚡ Esperar un frame antes de navegar para asegurar que HomeScreen esté montado
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ Verificar mounted después del await
      if (!mounted) {
        debugPrint('❌ Widget desmontado antes de navegar');
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(taskGroup: taskGroup),
        ),
      );

      debugPrint('✅ Navegación completada');
    } else {
      debugPrint('❌ Tarea no encontrada: $_pendingNotificationTaskId');
    }

    // Limpiar la variable global
    _pendingNotificationTaskId = null;
  }
}
