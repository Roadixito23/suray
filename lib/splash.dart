import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'home.dart';
import 'main.dart'; // Importar para acceder a los colores

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Control de carga de assets
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Iniciando...';
  bool _assetsLoaded = false;
  bool _hasError = false;

  // Lista de assets críticos para precargar
  final List<String> _criticalAssets = [
    'assets/logo.png',
    'assets/home_panels/buses.png',
    'assets/home_panels/aysen.png',
    'assets/home_panels/tunel.png',
    'assets/home_panels/terminal_coy.png',
    'assets/home_panels/puente_aysen.png',
    'assets/bg/background_route.png',
    'assets/ruta_240.png',
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();

    // Iniciar la precarga de assets
    _preloadAssets();
  }

  /// Precarga todos los assets críticos en segundo plano
  Future<void> _preloadAssets() async {
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

      // Esperar un mínimo de tiempo para que se vea la animación
      await Future.delayed(const Duration(milliseconds: 800));

      // Navegar a Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
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

      // Aún así navegar después de un tiempo
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
    super.dispose();
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
              MyApp.primaryOrange.withOpacity(0.8),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Patrón de fondo sutil
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
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

            // Contenido principal
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Container para el logo con efecto de brillo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MyApp.primaryOrange.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Título principal con animación
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: MyApp.primaryOrange,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: MyApp.primaryOrange.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Buses Suray',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Descripción adicional
                        Text(
                          'Ruta 240 • Servicios especiales',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 60),

                        // Indicador de carga personalizado con progreso
                        Column(
                          children: [
                            // Indicador circular con progreso
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _assetsLoaded ? null : _loadingProgress,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    strokeWidth: 3,
                                  ),
                                  if (!_assetsLoaded && _loadingProgress > 0)
                                    Text(
                                      '${(_loadingProgress * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Mensaje de estado
                            Text(
                              _loadingMessage,
                              style: TextStyle(
                                color: _hasError
                                    ? Colors.red.shade300
                                    : Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // Barra de progreso adicional para mejor visualización
                            if (!_assetsLoaded && _loadingProgress > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: 200,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _loadingProgress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: MyApp.primaryOrange,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: MyApp.primaryOrange.withOpacity(0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Versión en la esquina inferior
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'v01.08.25',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}