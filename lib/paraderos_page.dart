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
import 'config/api_keys.dart';

class ParaderosPage extends StatefulWidget {
  const ParaderosPage({super.key});

  @override
  State<ParaderosPage> createState() => _ParaderosPageState();
}

class _ParaderosPageState extends State<ParaderosPage>
    with TickerProviderStateMixin {
  // Coordenadas de los puntos
  final LatLng puertoAysen = const LatLng(-45.40111614852224, -72.68738064167634);
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

  // ScrollController para la barra de scroll horizontal
  final ScrollController _buttonsScrollController = ScrollController();

  // Info card del terminal
  String? _selectedTerminal;
  late AnimationController _cardAnimationController;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

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

    // Animación de la tarjeta de terminal (emerge desde abajo)
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    ));
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

  // TODO: Métodos de cálculo de distancias y triángulos animados removidos temporalmente
  // Se pueden reimplementar en el futuro usando capas dinámicas de Mapbox

  @override
  void dispose() {
    _routeAnimationController.dispose();
    _cardAnimationController.dispose();
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
                      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${ApiKeys.mapboxAccessToken}',
                  additionalOptions: {
                    'accessToken': ApiKeys.mapboxAccessToken,
                    'id': 'mapbox.streets',
                  },
                  userAgentPackageName: 'com.suray.app',
                  tileSize: 256,
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
                    // Puerto Aysén
                    // height=88 (2x tamaño del ícono): la punta del pin cae
                    // exactamente en el centro del widget = coordenada del mapa.
                    Marker(
                      point: puertoAysen,
                      width: 44,
                      height: 88,
                      child: GestureDetector(
                        onTap: () => _showTerminalCard('aysen'),
                        child: ValueListenableBuilder<double>(
                          valueListenable: _mapRotationNotifier,
                          builder: (context, rotation, _) {
                            return _buildPinMarker(
                              color: MyApp.primaryNavy,
                              rotation: rotation,
                            );
                          },
                        ),
                      ),
                    ),
                    // Coyhaique
                    Marker(
                      point: coyhaique,
                      width: 44,
                      height: 88,
                      child: GestureDetector(
                        onTap: () => _showTerminalCard('coyhaique'),
                        child: ValueListenableBuilder<double>(
                          valueListenable: _mapRotationNotifier,
                          builder: (context, rotation, _) {
                            return _buildPinMarker(
                              color: MyApp.accentBlue,
                              rotation: rotation,
                            );
                          },
                        ),
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

          // Tarjeta de información del terminal
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _cardSlideAnimation,
              child: _buildTerminalCard(),
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

  void _showTerminalCard(String terminal) {
    setState(() => _selectedTerminal = terminal);
    _cardAnimationController.forward();
  }

  void _hideTerminalCard() {
    if (_selectedTerminal == null) return;
    _cardAnimationController.reverse().then((_) {
      if (mounted) setState(() => _selectedTerminal = null);
    });
  }

  Widget _buildPinMarker({
    required Color color,
    required double rotation,
  }) {
    // Lógica de precisión:
    // - Marker.height = 88 (2× el tamaño del ícono)
    // - El centro del widget (y=44) coincide con la coordenada del mapa
    // - El ícono (44px) ocupa la MITAD SUPERIOR (y=0→44), con la punta en y=44
    // - Resultado: punta del pin = centro del widget = coordenada del mapa ✓
    // - Transform.rotate con pivot en Alignment.center (defecto) = pivot en y=44 = punta ✓
    return Transform.rotate(
      angle: -rotation * pi / 180,
      child: SizedBox(
        width: 44,
        height: 88,
        child: Align(
          alignment: Alignment.topCenter,
          child: Icon(
            Icons.location_on,
            color: color,
            size: 44,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalCard() {
    if (_selectedTerminal == null) return const SizedBox.shrink();

    final isAysen = _selectedTerminal == 'aysen';
    final color = isAysen ? MyApp.primaryNavy : MyApp.accentBlue;
    final description = isAysen ? 'Aysén Suray' : 'Coyhaique Suray';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Ícono del terminal
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Terminal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFamily: 'Hemiheads',
                      ),
                    ),
                  ],
                ),
              ),
              // Botón cerrar
              GestureDetector(
                onTap: _hideTerminalCard,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
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
// TODO: _TrianglePainter removido - no se usa con Mapbox

