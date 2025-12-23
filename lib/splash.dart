import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'home.dart';
import 'main.dart'; // Importar para acceder a los colores

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _circleAnimationController;
  late AnimationController _floatingController;
  late AnimationController _finishController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _floatingAnimation;

  // Control de carga de assets
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Iniciando...';
  bool _assetsLoaded = false;
  bool _hasError = false;
  bool _isFinishing = false;

  // Lista de assets críticos para precargar
  final List<String> _criticalAssets = [
    'assets/logo.png',
    'assets/home_panels/buses.png',
    'assets/home_panels/puente_aysen.png',
    'assets/home_panels/terminal_coy.png',
    'assets/home_panels/tunel.png',
    'assets/home_panels/aysen.png',
    'assets/bg/background_route.png',
    'assets/ruta_240.png',
  ];

  @override
  void initState() {
    super.initState();

    // Controlador principal de animaciones
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Controlador para círculos de fondo
    _circleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Animación de fade para el logo
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    );

    // Animación de escala con efecto bounce
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    // Animación de rotación sutil para el logo
    _logoRotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    ));

    // Animación de slide para elementos superiores
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    // Controlador para animación de flotación
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Animación de flotación
    _floatingAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    // Controlador para animación de finalización
    _finishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animationController.forward();

    // Iniciar la precarga de assets
    _preloadAssets();
  }

  /// Precarga todos los assets críticos en segundo plano
  Future<void> _preloadAssets() async {
    // Registrar el tiempo de inicio para garantizar un mínimo de 3 segundos
    final startTime = DateTime.now();
    const minSplashDuration = Duration(seconds: 3);

    try {
      setState(() {
        _loadingMessage = 'Cargando recursos...';
        _loadingProgress = 0.0;
      });

      // Precargar assets de manera asíncrona
      for (int i = 0; i < _criticalAssets.length; i++) {
        final assetPath = _criticalAssets[i];

        try {
          // Para web, precargar la imagen de manera diferente
          if (kIsWeb) {
            await _preloadImageWeb(assetPath);
          } else {
            await _preloadImageNative(assetPath);
          }

          // Actualizar progreso
          if (mounted) {
            setState(() {
              _loadingProgress = (i + 1) / _criticalAssets.length;
              _loadingMessage = 'Cargando ${i + 1}/${_criticalAssets.length} recursos...';
            });
          }
        } catch (e) {
          debugPrint('Error precargando $assetPath: $e');
          // Continuar con los demás assets aunque uno falle
        }
      }

      // Assets cargados exitosamente
      if (mounted) {
        setState(() {
          _assetsLoaded = true;
          _loadingMessage = 'Cargando horarios...';
          _loadingProgress = 1.0;
        });
      }

      // Calcular cuánto tiempo ha pasado
      final elapsedTime = DateTime.now().difference(startTime);
      final remainingTime = minSplashDuration - elapsedTime;

      // Si han pasado menos de 4 segundos, esperar el tiempo restante
      if (remainingTime.inMilliseconds > 0) {
        await Future.delayed(remainingTime);
      }

      // Activar animación de finalización
      if (mounted) {
        setState(() {
          _isFinishing = true;
        });

        // Acelerar el círculo y cambiar a azul neón
        _circleAnimationController.duration = const Duration(milliseconds: 300);
        _circleAnimationController.repeat();

        // Ejecutar animación de finalización
        await _finishController.forward();

        // Pequeña pausa para el efecto
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Navegar a Home con animación moderna estilo Material 3
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
            transitionDuration: const Duration(milliseconds: 900),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Animación principal con curva moderna
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubicEmphasized,
                reverseCurve: Curves.easeOutCubic,
              );

              // Fade suave y rápido
              final fadeAnimation = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
              ));

              // Zoom in sutil tipo hero transition
              final scaleAnimation = Tween<double>(
                begin: 0.92,
                end: 1.0,
              ).animate(curvedAnimation);

              // Slide vertical suave
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(curvedAnimation);

              // Fade out del splash (crossfade effect)
              final reverseFadeAnimation = Tween<double>(
                begin: 1.0,
                end: 0.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
              ));

              return Stack(
                children: [
                  // Fade out del splash screen
                  FadeTransition(
                    opacity: reverseFadeAnimation,
                    child: secondaryAnimation.status == AnimationStatus.completed
                        ? const SizedBox.shrink()
                        : Container(
                            color: MyApp.primaryNavy,
                          ),
                  ),
                  // Fade in, scale y slide del home
                  FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: child,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en la precarga de assets: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _loadingMessage = 'Error cargando recursos';
        });
      }

      // Esperar al menos 2 segundos para mostrar el error
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  /// Precarga una imagen para web usando ImageProvider
  Future<void> _preloadImageWeb(String assetPath) async {
    final ImageProvider imageProvider = AssetImage(assetPath);
    final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
    final Completer<void> completer = Completer<void>();

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        stream.removeListener(listener);
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);

    // Timeout de 10 segundos por imagen
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        stream.removeListener(listener);
        throw TimeoutException('Timeout cargando $assetPath');
      },
    );
  }

  /// Precarga una imagen para plataformas nativas
  Future<void> _preloadImageNative(String assetPath) async {
    final ImageProvider imageProvider = AssetImage(assetPath);
    await precacheImage(imageProvider, context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _circleAnimationController.dispose();
    _floatingController.dispose();
    _finishController.dispose();
    super.dispose();
  }

  // Widget para círculos animados de fondo
  Widget _buildAnimatedCircles() {
    return AnimatedBuilder(
      animation: _circleAnimationController,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Círculo 1 - Arriba izquierda
                Positioned(
                  top: -100 + (50 * _circleAnimationController.value),
                  left: -100 + (30 * _circleAnimationController.value),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          MyApp.primaryNavy.withValues(alpha: 0.3),
                          MyApp.primaryNavy.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Círculo 2 - Arriba derecha
                Positioned(
                  top: 50 - (40 * _circleAnimationController.value),
                  right: -80 - (20 * _circleAnimationController.value),
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          MyApp.primaryOrange.withValues(alpha: 0.2),
                          MyApp.primaryOrange.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Círculo 3 - Centro
                Positioned(
                  top: constraints.maxHeight / 2 - 150 + (30 * _circleAnimationController.value),
                  left: constraints.maxWidth / 2 - 150 - (40 * _circleAnimationController.value),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MyApp.lightNavy.withValues(alpha: 0.25),
                      MyApp.lightNavy.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Círculo 4 - Abajo izquierda
            Positioned(
              bottom: -120 - (60 * _circleAnimationController.value),
              left: 20 + (50 * _circleAnimationController.value),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MyApp.primaryOrange.withValues(alpha: 0.25),
                      MyApp.primaryOrange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Círculo 5 - Abajo derecha
            Positioned(
              bottom: -50 + (70 * _circleAnimationController.value),
              right: -120 + (30 * _circleAnimationController.value),
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MyApp.accentBlue.withValues(alpha: 0.2),
                      MyApp.accentBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MyApp.primaryNavy,
              MyApp.lightNavy,
              MyApp.primaryOrange.withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Patrón de fondo sutil
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/home_panels/buses.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            // Círculos animados de fondo
            Positioned.fill(
              child: _buildAnimatedCircles(),
            ),

            // Contenido principal - Logo centrado con animaciones
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: AnimatedBuilder(
                      animation: _floatingAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatingAnimation.value),
                          child: child,
                        );
                      },
                      child: RotationTransition(
                        turns: _logoRotationAnimation,
                        child: SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Círculo de carga simple y limpio
                              AnimatedBuilder(
                                animation: Listenable.merge([_circleAnimationController, _finishController]),
                                builder: (context, child) {
                                  // Color fijo naranja para el cargador
                                  final Color circleColor = MyApp.primaryOrange;

                                  return Container(
                                    width: 260,
                                    height: 260,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: circleColor.withValues(alpha: 0.3),
                                          blurRadius: 20.0,
                                          spreadRadius: 5.0,
                                        ),
                                      ],
                                    ),
                                    child: RotationTransition(
                                      turns: _circleAnimationController,
                                      child: SizedBox(
                                        width: 260,
                                        height: 260,
                                        child: CircularProgressIndicator(
                                          value: 0.75,
                                          strokeWidth: 5.0,
                                          valueColor: AlwaysStoppedAnimation<Color>(circleColor),
                                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Logo circular en el centro con sombra simple
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: MyApp.primaryOrange.withValues(alpha: 0.3),
                                      blurRadius: 25.0,
                                      spreadRadius: 5.0,
                                    ),
                                    BoxShadow(
                                      color: MyApp.primaryNavy.withValues(alpha: 0.4),
                                      blurRadius: 40,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/logocircle.png',
                                    width: 220,
                                    height: 220,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}