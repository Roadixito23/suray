import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';
import 'route_data.dart';
import 'floating_notification.dart';

class ParaderosPage extends StatefulWidget {
  const ParaderosPage({super.key});

  @override
  State<ParaderosPage> createState() => _ParaderosPageState();
}

class _ParaderosPageState extends State<ParaderosPage>
    with TickerProviderStateMixin {
  // Coordenadas de los puntos
  final LatLng puertoAysen = const LatLng(-45.401077, -72.687320);
  final LatLng coyhaique = const LatLng(-45.582039, -72.078136);
  final LatLng centerPoint = const LatLng(-45.4915, -72.3827);

  // Controller del mapa
  final MapController mapController = MapController();

  // Puntos de las rutas siguiendo la carretera
  static final List<LatLng> _routeAysToCoy =
      RouteData.routeAysToCoy; // Aysén -> Coyhaique
  static final List<LatLng> _routeCoyToAys =
      RouteData.routeCoyToAys; // Coyhaique -> Aysén

  // Dirección de la ruta actual (true = AYS->COY, false = COY->AYS)
  bool _isAysToCoy = true;

  // Geolocalización
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationMessage;

  // Rotación del mapa con ValueNotifier para forzar rebuilds
  final ValueNotifier<double> _mapRotationNotifier = ValueNotifier<double>(0.0);

  // Stream subscription para eventos del mapa en tiempo real
  StreamSubscription<MapEvent>? _mapEventSubscription;

  // Animación de triángulos viajando por la ruta
  late AnimationController _routeAnimationController;
  final List<double> _trianglePositions = [0.0, 0.5]; // 2 triángulos espaciados

  // Cache de distancias acumuladas para velocidad constante
  List<double> _routeDistancesAysToCoy = [];
  List<double> _routeDistancesCoyToAys = [];
  double _totalDistanceAysToCoy = 0.0;
  double _totalDistanceCoyToAys = 0.0;

  // ScrollController para la barra de scroll horizontal
  final ScrollController _buttonsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    
    // Precalcular distancias acumuladas para ambas rutas
    _routeDistancesAysToCoy = _calculateCumulativeDistances(_routeAysToCoy);
    _routeDistancesCoyToAys = _calculateCumulativeDistances(_routeCoyToAys);
    _totalDistanceAysToCoy = _routeDistancesAysToCoy.isNotEmpty 
        ? _routeDistancesAysToCoy.last 
        : 0.0;
    _totalDistanceCoyToAys = _routeDistancesCoyToAys.isNotEmpty 
        ? _routeDistancesCoyToAys.last 
        : 0.0;

    // Inicializar animación de triángulos
    _routeAnimationController =
        AnimationController(
            vsync: this,
            duration: const Duration(
              seconds: 69,
            ), // 69 segundos para recorrer toda la ruta
          )
          ..addListener(() {
            // Forzar rebuild para actualizar posiciones de triángulos
            if (mounted) setState(() {});
          })
          ..repeat(); // Repetir indefinidamente

    // Escuchar eventos del mapa en tiempo real para detectar rotación
    _mapEventSubscription = mapController.mapEventStream.listen((event) {
      // Actualizar rotación en tiempo real
      final currentRotation = mapController.camera.rotation;
      if (_mapRotationNotifier.value != currentRotation) {
        _mapRotationNotifier.value = currentRotation;
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      // Verificar si el servicio de localización está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationMessage = 'GPS desactivado';
          _isLoadingLocation = false;
        });
        return;
      }

      // Verificar y solicitar permisos (en web, esto activará el diálogo del navegador)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationMessage = 'Permiso denegado';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage = 'Permiso bloqueado';
          _isLoadingLocation = false;
        });
        return;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      // Verificar si está dentro de los límites del mapa
      bool isInBounds = _isWithinMapBounds(position);

      setState(() {
        if (isInBounds) {
          _currentPosition = position;
          _locationMessage = null;
          if (mounted) {
            FloatingNotification.show(
              context,
              message: 'Ubicación encontrada',
              type: NotificationType.success,
              duration: const Duration(seconds: 2),
            );
          }
        } else {
          _currentPosition = null;
          _locationMessage = 'Fuera del área';
          if (mounted) {
            FloatingNotification.show(
              context,
              message:
                  'Tu ubicación está fuera de la zona Puerto Aysén - Coyhaique',
              type: NotificationType.info,
              duration: const Duration(seconds: 4),
            );
          }
        }
        _isLoadingLocation = false;
      });
    } catch (e) {
      // Mostrar error específico al usuario
      setState(() {
        _locationMessage = 'Error al obtener ubicación';
        _isLoadingLocation = false;
      });
      if (mounted) {
        FloatingNotification.show(
          context,
          message: 'No se pudo obtener tu ubicación. Toca el botón de ubicación para intentar nuevamente.',
          type: NotificationType.info,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  bool _isWithinMapBounds(Position position) {
    // Límites del mapa (los mismos que cameraConstraint)
    const double minLat = -45.82;
    const double maxLat = -45.19;
    const double minLng = -73.0;
    const double maxLng = -71.8;

    return position.latitude >= minLat &&
        position.latitude <= maxLat &&
        position.longitude >= minLng &&
        position.longitude <= maxLng;
  }

  // Calcular distancias acumuladas entre puntos de la ruta
  List<double> _calculateCumulativeDistances(List<LatLng> route) {
    if (route.isEmpty) return [];
    
    final distances = <double>[0.0];
    double accumulated = 0.0;
    
    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final current = route[i];
      
      // Calcular distancia euclidiana (aproximación)
      final latDiff = current.latitude - prev.latitude;
      final lonDiff = current.longitude - prev.longitude;
      final distance = sqrt(latDiff * latDiff + lonDiff * lonDiff);
      
      accumulated += distance;
      distances.add(accumulated);
    }
    
    return distances;
  }

  // Interpolar posición basada en distancia recorrida
  LatLng _interpolateByDistance(
    List<LatLng> route,
    List<double> distances,
    double targetDistance,
  ) {
    if (route.isEmpty || distances.isEmpty) {
      return const LatLng(0, 0);
    }

    // Encontrar el segmento donde está la distancia objetivo
    int segmentIndex = 0;
    for (int i = 0; i < distances.length - 1; i++) {
      if (targetDistance >= distances[i] && targetDistance <= distances[i + 1]) {
        segmentIndex = i;
        break;
      }
    }

    // Si estamos al final, retornar último punto
    if (segmentIndex >= route.length - 1) {
      return route.last;
    }

    final currentPoint = route[segmentIndex];
    final nextPoint = route[segmentIndex + 1];
    final segmentStart = distances[segmentIndex];
    final segmentEnd = distances[segmentIndex + 1];
    final segmentLength = segmentEnd - segmentStart;

    // Interpolar dentro del segmento
    final t = segmentLength > 0 
        ? (targetDistance - segmentStart) / segmentLength 
        : 0.0;

    final lat = currentPoint.latitude + 
        (nextPoint.latitude - currentPoint.latitude) * t;
    final lon = currentPoint.longitude + 
        (nextPoint.longitude - currentPoint.longitude) * t;

    return LatLng(lat, lon);
  }

  // Calcular ángulo de dirección en un punto de la ruta
  double _calculateAngleAtDistance(
    List<LatLng> route,
    List<double> distances,
    double targetDistance,
  ) {
    if (route.isEmpty || distances.isEmpty) return 0.0;

    // Encontrar el segmento
    int segmentIndex = 0;
    for (int i = 0; i < distances.length - 1; i++) {
      if (targetDistance >= distances[i] && targetDistance <= distances[i + 1]) {
        segmentIndex = i;
        break;
      }
    }

    if (segmentIndex >= route.length - 1) {
      segmentIndex = route.length - 2;
    }

    final currentPoint = route[segmentIndex];
    final nextPoint = route[segmentIndex + 1];

    return atan2(
      nextPoint.longitude - currentPoint.longitude,
      nextPoint.latitude - currentPoint.latitude,
    );
  }

  @override
  void dispose() {
    _routeAnimationController.dispose();
    _mapEventSubscription?.cancel();
    _mapRotationNotifier.dispose();
    _buttonsScrollController.dispose();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa con soporte para rotación Ctrl+Scroll
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: (event) {
              if (event is PointerScrollEvent &&
                  HardwareKeyboard.instance.isControlPressed) {
                // Rotar el mapa con Ctrl+Scroll
                final rotationDelta = event.scrollDelta.dy * 0.5;
                final newRotation =
                    (_mapRotationNotifier.value + rotationDelta) % 360;
                _mapRotationNotifier.value = newRotation;
                mapController.rotate(newRotation);
              }
            },
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: 9.5,
                minZoom: 9.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(-45.82, -73.0),
                    const LatLng(-45.19, -71.8),
                  ),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets-v4/{z}/{x}/{y}.png?key=JlwBUJ8jYaM19HSPdZrv',
                  userAgentPackageName: 'com.suray.app',
                ),
                // Ruta que sigue las carreteras
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _isAysToCoy ? _routeAysToCoy : _routeCoyToAys,
                      strokeWidth: 4.0,
                      color:
                          _isAysToCoy ? MyApp.primaryOrange : MyApp.accentBlue,
                      borderStrokeWidth: 2.0,
                      borderColor: MyApp.primaryNavy,
                    ),
                  ],
                ),
                // Marcadores
                MarkerLayer(
                  markers: [
                    // Ubicación del usuario
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 3),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.circle,
                              color: Colors.blue,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    // Triángulos animados en la ruta
                    ..._buildAnimatedTriangles(),
                    // Puerto Aysén
                    Marker(
                      point: puertoAysen,
                      width: 80,
                      height: 80,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _mapRotationNotifier,
                        builder: (context, rotation, _) {
                          return _buildRotatingMarker(
                            label: 'Puerto Aysén',
                            color: MyApp.primaryNavy,
                            rotation: rotation,
                          );
                        },
                      ),
                    ),
                    // Coyhaique
                    Marker(
                      point: coyhaique,
                      width: 80,
                      height: 80,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _mapRotationNotifier,
                        builder: (context, rotation, _) {
                          return _buildRotatingMarker(
                            label: 'Coyhaique',
                            color: MyApp.accentBlue,
                            rotation: rotation,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Header flotante mejorado con diseño responsivo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MyApp.primaryNavy.withOpacity(0.95),
                    MyApp.primaryNavy.withOpacity(0.85),
                    MyApp.primaryNavy.withOpacity(0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primera fila: Botón volver + Título
                  Row(
                    children: [
                      // Botón de volver
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Título expandido
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                MyApp.primaryOrange.withOpacity(0.9),
                                MyApp.primaryOrange.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MyApp.primaryOrange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'Ruta Buses Suray',
                              style: TextStyle(
                                fontFamily: 'Hemiheads',
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Segunda fila: Botones de zoom y navegación con scroll horizontal
                  Scrollbar(
                    controller: _buttonsScrollController,
                    thumbVisibility: true,
                    thickness: 3.0,
                    radius: const Radius.circular(10),
                    trackVisibility: true,
                    child: ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.8)),
                        trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.2)),
                        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
                        thickness: WidgetStateProperty.all(3.0),
                        radius: const Radius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        controller: _buttonsScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botón de ubicación (siempre visible)
                        _buildLocationButton(),
                        const SizedBox(width: 8),
                        // Botones de zoom
                        _buildZoomButton(
                          icon: Icons.remove,
                          onTap: () {
                            final currentZoom = mapController.camera.zoom;
                            mapController.move(
                              mapController.camera.center,
                              (currentZoom - 1).clamp(9.0, 18.0),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        _buildZoomButton(
                          icon: Icons.add,
                          onTap: () {
                            final currentZoom = mapController.camera.zoom;
                            mapController.move(
                              mapController.camera.center,
                              (currentZoom + 1).clamp(9.0, 18.0),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Botón AYS (Puerto Aysén)
                        _buildQuickNavButton(
                          label: 'AYS',
                          color: MyApp.primaryNavy,
                          onTap: () {
                            mapController.move(puertoAysen, 13.0);
                          },
                        ),
                        const SizedBox(width: 4),
                        // Botón de flecha para cambiar dirección de ruta
                        _buildDirectionButton(),
                        const SizedBox(width: 4),
                        // Botón COY (Coyhaique)
                        _buildQuickNavButton(
                          label: 'COY',
                          color: MyApp.accentBlue,
                          onTap: () {
                            mapController.move(coyhaique, 13.0);
                          },
                        ),
                      ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Mensaje de ubicación fuera del área
          if (_locationMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 90,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locationMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón X para cerrar
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _locationMessage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Brújula estilo Google Maps - con ValueListenableBuilder para rebuild
          Positioned(
            top: 140,
            right: 16,
            child: ValueListenableBuilder<double>(
              valueListenable: _mapRotationNotifier,
              builder: (context, rotation, _) {
                return _buildCompassRose(rotation);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.95), color.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Construir triángulos animados que viajan por la ruta con velocidad constante
  List<Marker> _buildAnimatedTriangles() {
    final route = _isAysToCoy ? _routeAysToCoy : _routeCoyToAys;
    final distances = _isAysToCoy ? _routeDistancesAysToCoy : _routeDistancesCoyToAys;
    final totalDistance = _isAysToCoy ? _totalDistanceAysToCoy : _totalDistanceCoyToAys;
    
    if (route.isEmpty || distances.isEmpty || totalDistance == 0) return [];

    return _trianglePositions.map((offset) {
      // Calcular distancia recorrida basada en el progreso de la animación
      final progress = (_routeAnimationController.value + offset) % 1.0;
      final targetDistance = progress * totalDistance;

      // Interpolar posición basada en distancia (velocidad constante)
      final position = _interpolateByDistance(route, distances, targetDistance);

      // Calcular ángulo de rotación basado en la dirección en ese punto
      final angle = _calculateAngleAtDistance(route, distances, targetDistance);

      return Marker(
        point: position,
        width: 24,
        height: 24,
        child: Transform.rotate(
          angle: angle,
          child: CustomPaint(
            size: const Size(24, 24),
            painter: _TrianglePainter(),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF64B5F6).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_currentPosition != null) {
              // Si ya tenemos ubicación, centrar el mapa
              mapController.move(
                LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                14.0,
              );
            } else {
              // Si no tenemos ubicación, solicitarla
              _getCurrentLocation();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    _currentPosition != null
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              _isAysToCoy
                  ? [
                    MyApp.primaryOrange.withOpacity(0.95),
                    MyApp.primaryOrange.withOpacity(0.85),
                  ]
                  : [
                    MyApp.accentBlue.withOpacity(0.95),
                    MyApp.accentBlue.withOpacity(0.85),
                  ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: (_isAysToCoy ? MyApp.primaryOrange : MyApp.accentBlue)
                .withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isAysToCoy = !_isAysToCoy;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Icon(
              _isAysToCoy
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotatingMarker({
    required String label,
    required Color color,
    required double rotation,
  }) {
    return Transform.rotate(
      angle: -rotation * pi / 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.location_on,
            color: color,
            size: 40,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompassRose(double rotation) {
    // Brújula estilo Google Maps - al tocar resetea al norte
    return GestureDetector(
      onTap: () {
        // Al tocar, resetear la rotación del mapa al norte (0°)
        _mapRotationNotifier.value = 0.0;
        mapController.rotate(0.0);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: MyApp.primaryOrange.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: MyApp.primaryOrange.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
          // La aguja gira en el mismo sentido que la rotación del mapa
          angle: rotation * pi / 180,
          child: CustomPaint(
            size: const Size(48, 48),
            painter: _GoogleMapsCompassPainter(),
          ),
        ),
      ),
    );
  }
}

// Pintor de brújula estilo Google Maps con colores Suray
class _GoogleMapsCompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final needleLength = size.width * 0.38;

    // Punta norte (naranja pastel vibrante)
    final northPaint =
        Paint()
          ..color = const Color(0xFFFFB347) // Naranja pastel
          ..style = PaintingStyle.fill;

    final northPath =
        ui.Path()
          ..moveTo(center.dx, center.dy - needleLength) // Punta
          ..lineTo(center.dx - 6, center.dy) // Base izquierda
          ..lineTo(center.dx + 6, center.dy) // Base derecha
          ..close();

    canvas.drawPath(northPath, northPaint);

    // Borde naranja más oscuro para la punta norte
    final northBorderPaint =
        Paint()
          ..color = MyApp.primaryOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawPath(northPath, northBorderPaint);

    // Punta sur (azul pastel)
    final southPaint =
        Paint()
          ..color = const Color(0xFF87CEEB) // Azul pastel (sky blue)
          ..style = PaintingStyle.fill;

    final southPath =
        ui.Path()
          ..moveTo(center.dx, center.dy + needleLength) // Punta
          ..lineTo(center.dx - 6, center.dy) // Base izquierda
          ..lineTo(center.dx + 6, center.dy) // Base derecha
          ..close();

    canvas.drawPath(southPath, southPaint);

    // Borde azul para la punta sur
    final southBorderPaint =
        Paint()
          ..color = MyApp.accentBlue.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawPath(southPath, southBorderPaint);

    // Círculo central blanco
    final centerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);

    // Borde del círculo central
    final centerBorderPaint =
        Paint()
          ..color = MyApp.primaryOrange.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawCircle(center, 4, centerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pintor de triángulo blanco para indicar dirección del viaje
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = MyApp.primaryNavy.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);

    // Triángulo apuntando hacia arriba (dirección del viaje)
    final path =
        ui.Path()
          ..moveTo(center.dx, center.dy - 8) // Punta superior
          ..lineTo(center.dx - 6, center.dy + 6) // Base izquierda
          ..lineTo(center.dx + 6, center.dy + 6) // Base derecha
          ..close();

    // Rellenar triángulo
    canvas.drawPath(path, paint);

    // Borde del triángulo
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
