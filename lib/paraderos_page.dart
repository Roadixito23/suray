import 'dart:math';
import 'package:flutter/material.dart';
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

class _ParaderosPageState extends State<ParaderosPage> {
  // Coordenadas de los puntos
  final LatLng puertoAysen = const LatLng(-45.401077, -72.687320);
  final LatLng coyhaique = const LatLng(-45.582039, -72.078136);
  final LatLng centerPoint = const LatLng(-45.4915, -72.3827);

  // Controller del mapa
  final MapController mapController = MapController();

  // Puntos de la ruta real siguiendo la carretera (2104 puntos)
  static final List<LatLng> _routePoints = RouteData.points;

  // Geolocalización
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationMessage;

  // Rotación del mapa
  double _mapRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
        if (mounted) {
          FloatingNotification.show(
            context,
            message: 'Activa el GPS en tu dispositivo para ver tu ubicación en el mapa',
            type: NotificationType.warning,
            duration: const Duration(seconds: 4),
          );
        }
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationMessage = 'Permiso denegado';
            _isLoadingLocation = false;
          });
          if (mounted) {
            FloatingNotification.show(
              context,
              message: 'Necesitamos tu permiso para mostrar tu ubicación en el mapa',
              type: NotificationType.warning,
              duration: const Duration(seconds: 4),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage = 'Permiso bloqueado';
          _isLoadingLocation = false;
        });
        if (mounted) {
          FloatingNotification.show(
            context,
            message: 'Los permisos de ubicación están bloqueados. Actívalos en la configuración de tu navegador',
            type: NotificationType.error,
            duration: const Duration(seconds: 5),
          );
        }
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
              message: 'Tu ubicación está fuera de la zona Puerto Aysén - Coyhaique',
              type: NotificationType.info,
              duration: const Duration(seconds: 4),
            );
          }
        }
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationMessage = 'Error de ubicación';
        _isLoadingLocation = false;
      });
      if (mounted) {
        FloatingNotification.show(
          context,
          message: 'No se pudo obtener tu ubicación. Verifica tu conexión y permisos',
          type: NotificationType.error,
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

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: 9.5,
              minZoom: 9.0,
              maxZoom: 18.0, // Aumentado para ver las calles en detalle
              // Límites del mapa para mantenerlo centrado en la región
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-45.82, -73.0), // Suroeste
                  const LatLng(-45.19, -71.8), // Noreste
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
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: MyApp.primaryOrange,
                    borderStrokeWidth: 2.0,
                    borderColor: MyApp.primaryNavy,
                  ),
                ],
              ),
              // Marcadores
              MarkerLayer(
                markers: [
                  // Ubicación del usuario (solo si está dentro del mapa)
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
                  Marker(
                    point: puertoAysen,
                    width: 80,
                    height: 80,
                    child: Transform.rotate(
                      angle: -_mapRotation * pi / 180,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MyApp.primaryNavy,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Puerto Aysén',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.location_on,
                            color: MyApp.primaryNavy,
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
                    ),
                  ),
                  // Coyhaique
                  Marker(
                    point: coyhaique,
                    width: 80,
                    height: 80,
                    child: Transform.rotate(
                      angle: -_mapRotation * pi / 180,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MyApp.accentBlue,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Coyhaique',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.location_on,
                            color: MyApp.accentBlue,
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
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Header flotante mejorado
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
                    MyApp.primaryNavy,
                    MyApp.primaryNavy.withOpacity(0.95),
                    MyApp.primaryNavy.withOpacity(0.7),
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
                children: [
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
                      // Título
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ruta',
                              style: TextStyle(
                                fontFamily: 'Hemiheads',
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.route,
                                  color: MyApp.primaryOrange,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                const Flexible(
                                  child: Text(
                                    'Puerto Aysén - Coyhaique',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Controles de zoom compactos
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                final currentZoom = mapController.camera.zoom;
                                mapController.move(
                                  mapController.camera.center,
                                  currentZoom + 1,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            InkWell(
                              onTap: () {
                                final currentZoom = mapController.camera.zoom;
                                mapController.move(
                                  mapController.camera.center,
                                  currentZoom - 1,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Panel de navegación reorganizado (derecha)
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Botón Mi Ubicación (si está disponible)
                if (_currentPosition != null)
                  _buildNavigationButton(
                    icon: Icons.my_location_rounded,
                    label: 'Mi Ubicación',
                    color: const Color(0xFF2196F3),
                    onTap: () {
                      mapController.move(
                        LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        14.0,
                      );
                    },
                  ),
                const SizedBox(height: 12),
                // Botón Puerto Aysén
                _buildNavigationButton(
                  icon: Icons.location_city,
                  label: 'Puerto Aysén',
                  color: MyApp.primaryNavy,
                  onTap: () {
                    mapController.move(puertoAysen, 13.0);
                  },
                ),
                const SizedBox(height: 12),
                // Botón Coyhaique
                _buildNavigationButton(
                  icon: Icons.apartment_rounded,
                  label: 'Coyhaique',
                  color: MyApp.accentBlue,
                  onTap: () {
                    mapController.move(coyhaique, 13.0);
                  },
                ),
              ],
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
                  ],
                ),
              ),
            ),

          // Rosa de los vientos mejorada con instrucciones
          Positioned(
            bottom: 20,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instrucción
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MyApp.primaryNavy.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: MyApp.primaryOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Arrastra para rotar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildCompassRose(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompassRose() {
    return GestureDetector(
      onPanUpdate: (details) {
        // Calcular el ángulo basado en la posición del toque
        final center = const Offset(60, 60); // Centro del widget (120/2)
        final touchPosition = details.localPosition;
        
        // Calcular el ángulo desde el centro hasta el punto tocado
        final dx = touchPosition.dx - center.dx;
        final dy = touchPosition.dy - center.dy;
        
        // Calcular ángulo en radianes y convertir a grados
        // atan2 da el ángulo desde el eje X positivo, en sentido antihorario
        var angleRadians = atan2(dy, dx);
        var angleDegrees = angleRadians * 180 / pi;
        
        // Ajustar para que 0° sea arriba (norte) en lugar de derecha
        // Y que gire en sentido horario (como una brújula real)
        angleDegrees = (angleDegrees + 90) % 360;
        
        setState(() {
          _mapRotation = angleDegrees;
        });
        
        // Rotar el mapa - en flutter_map, valores positivos rotan en sentido horario
        mapController.rotate(angleDegrees);
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Anillo exterior giratorio
            Transform.rotate(
              angle: _mapRotation * pi / 180,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MyApp.primaryNavy.withOpacity(0.2),
                    width: 8,
                  ),
                ),
                child: Stack(
                  children: [
                    // Indicador naranja pastel (marcador de orientación)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB347), // Naranja pastel
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB347).withOpacity(0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Círculo interior fijo (rosa de los vientos)
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MyApp.primaryNavy.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Círculo de fondo con gradiente
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            MyApp.lightGreyBackground.withOpacity(0.3),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                    
                    // Líneas divisorias
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _CompassLinePainter(),
                    ),

                    // Puntos cardinales
                    Center(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          children: [
                            // Norte (arriba)
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MyApp.primaryNavy,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'N',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Sur (abajo)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: MyApp.primaryNavy.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Este (derecha)
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Text(
                                  'E',
                                  style: TextStyle(
                                    color: MyApp.primaryNavy.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Oeste (izquierda)
                            Positioned(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Text(
                                  'O',
                                  style: TextStyle(
                                    color: MyApp.primaryNavy.withOpacity(0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Centro con flecha norte
                            Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: MyApp.primaryOrange,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: MyApp.primaryOrange.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pintor personalizado para las líneas de la rosa de los vientos
class _CompassLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MyApp.primaryNavy.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Líneas principales (N-S, E-O)
    // Norte-Sur
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 10),
      Offset(center.dx, center.dy + radius - 10),
      paint,
    );

    // Este-Oeste
    canvas.drawLine(
      Offset(center.dx - radius + 10, center.dy),
      Offset(center.dx + radius - 10, center.dy),
      paint,
    );

    // Líneas secundarias (diagonales)
    final paintSecondary = Paint()
      ..color = MyApp.primaryNavy.withOpacity(0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // NE-SO
    canvas.drawLine(
      Offset(center.dx - radius * 0.6, center.dy - radius * 0.6),
      Offset(center.dx + radius * 0.6, center.dy + radius * 0.6),
      paintSecondary,
    );

    // NO-SE
    canvas.drawLine(
      Offset(center.dx - radius * 0.6, center.dy + radius * 0.6),
      Offset(center.dx + radius * 0.6, center.dy - radius * 0.6),
      paintSecondary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
