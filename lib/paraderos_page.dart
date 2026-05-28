import 'dart:async';
import 'dart:math' show pi;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';
import 'floating_notification.dart';

class ParaderosPage extends StatefulWidget {
  const ParaderosPage({super.key});

  @override
  State<ParaderosPage> createState() => _ParaderosPageState();
}

class _ParaderosPageState extends State<ParaderosPage>
    with TickerProviderStateMixin {
  // Coordenadas de los puntos
  static const LatLng puertoAysen = LatLng(
    -45.40111614852224,
    -72.68738064167634,
  );
  static const LatLng coyhaique = LatLng(-45.582039, -72.078136);
  static const LatLng centerPoint = LatLng(-45.4915, -72.3827);

  // Controller del mapa
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  GoogleMapController? _mapController;
  double _currentZoom = 9.5;
  LatLng _currentCenter = centerPoint;

  // Dirección de la ruta actual (true = AYS->COY, false = COY->AYS)
  bool _isAysToCoy = true;

  // Geolocalización
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationMessage;

  // Ícono personalizado para la ubicación del usuario
  BitmapDescriptor? _userLocationIcon;

  // Rotación del mapa con ValueNotifier para forzar rebuilds
  final ValueNotifier<double> _mapRotationNotifier = ValueNotifier<double>(0.0);

  // ScrollController para la barra de scroll horizontal
  final ScrollController _buttonsScrollController = ScrollController();

  // Info card del terminal
  String? _selectedTerminal;
  late AnimationController _cardAnimationController;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _buildUserLocationIcon();
    _getCurrentLocation();

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _buildUserLocationIcon() async {
    const int size = 48;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Sombra exterior
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      16,
      Paint()
        ..color = const Color(0xFF2196F3).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    // Borde blanco
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      11,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    // Punto azul
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      8,
      Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.fill,
    );

    final ui.Image image = await recorder.endRecording().toImage(size, size);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData != null && mounted) {
      setState(() {
        _userLocationIcon = BitmapDescriptor.bytes(
          byteData.buffer.asUint8List(),
        );
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationMessage = 'GPS desactivado';
          _isLoadingLocation = false;
        });
        return;
      }

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

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

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
      setState(() {
        _locationMessage = 'Error al obtener ubicación';
        _isLoadingLocation = false;
      });
      if (mounted) {
        FloatingNotification.show(
          context,
          message:
              'No se pudo obtener tu ubicación. Toca el botón de ubicación para intentar nuevamente.',
          type: NotificationType.info,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  bool _isWithinMapBounds(Position position) {
    const double minLat = -45.82;
    const double maxLat = -45.19;
    const double minLng = -73.0;
    const double maxLng = -71.8;

    return position.latitude >= minLat &&
        position.latitude <= maxLat &&
        position.longitude >= minLng &&
        position.longitude <= maxLng;
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('aysen'),
        position: puertoAysen,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        onTap: () => _showTerminalCard('aysen'),
      ),
      Marker(
        markerId: const MarkerId('coyhaique'),
        position: coyhaique,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        onTap: () => _showTerminalCard('coyhaique'),
      ),
      if (_currentPosition != null)
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon:
              _userLocationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
    };
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _mapRotationNotifier.dispose();
    _buttonsScrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa Google Maps
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: centerPoint,
              zoom: 9.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_mapControllerCompleter.isCompleted) {
                _mapControllerCompleter.complete(controller);
              }
            },
            onCameraMove: (position) {
              _currentCenter = position.target;
              _currentZoom = position.zoom;
              final bearing = position.bearing;
              if ((_mapRotationNotifier.value - bearing).abs() > 0.1) {
                _mapRotationNotifier.value = bearing;
              }
            },
            markers: _buildMarkers(),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(9.0, 18.0),
            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                southwest: const LatLng(-45.82, -73.0),
                northeast: const LatLng(-45.19, -71.8),
              ),
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
                    MyApp.primaryNavy.withValues(alpha: 0.95),
                    MyApp.primaryNavy.withValues(alpha: 0.85),
                    MyApp.primaryNavy.withValues(alpha: 0.5),
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
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
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
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                MyApp.primaryOrange.withValues(alpha: 0.9),
                                MyApp.primaryOrange.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MyApp.primaryOrange.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
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
                  Scrollbar(
                    controller: _buttonsScrollController,
                    thumbVisibility: true,
                    thickness: 3.0,
                    radius: const Radius.circular(10),
                    trackVisibility: true,
                    child: ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                        trackColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.2),
                        ),
                        trackBorderColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                        thickness: WidgetStateProperty.all(3.0),
                        radius: const Radius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        controller: _buttonsScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLocationButton(),
                            const SizedBox(width: 8),
                            _buildZoomButton(
                              icon: Icons.remove,
                              onTap: () {
                                _mapController?.animateCamera(
                                  CameraUpdate.zoomOut(),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildZoomButton(
                              icon: Icons.add,
                              onTap: () {
                                _mapController?.animateCamera(
                                  CameraUpdate.zoomIn(),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildQuickNavButton(
                              label: 'AYS',
                              color: MyApp.primaryNavy,
                              onTap: () {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(puertoAysen, 13.0),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildDirectionButton(),
                            const SizedBox(width: 4),
                            _buildQuickNavButton(
                              label: 'COY',
                              color: MyApp.accentBlue,
                              onTap: () {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(coyhaique, 13.0),
                                );
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
                      color: Colors.black.withValues(alpha: 0.2),
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
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _locationMessage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
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

          // Brújula
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
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
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

  Widget _buildLocationButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF64B5F6).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.4),
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
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  14.0,
                ),
              );
            } else {
              _getCurrentLocation();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                _isLoadingLocation
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
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
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
                    MyApp.primaryOrange.withValues(alpha: 0.95),
                    MyApp.primaryOrange.withValues(alpha: 0.85),
                  ]
                  : [
                    MyApp.accentBlue.withValues(alpha: 0.95),
                    MyApp.accentBlue.withValues(alpha: 0.85),
                  ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isAysToCoy ? MyApp.primaryOrange : MyApp.accentBlue)
                .withValues(alpha: 0.4),
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
    return GestureDetector(
      onTap: () {
        _mapRotationNotifier.value = 0.0;
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentCenter,
              zoom: _currentZoom,
              bearing: 0.0,
            ),
          ),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: MyApp.primaryOrange.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: MyApp.primaryOrange.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
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

class _GoogleMapsCompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final needleLength = size.width * 0.38;

    final northPaint =
        Paint()
          ..color = const Color(0xFFFFB347)
          ..style = PaintingStyle.fill;

    final northPath =
        ui.Path()
          ..moveTo(center.dx, center.dy - needleLength)
          ..lineTo(center.dx - 6, center.dy)
          ..lineTo(center.dx + 6, center.dy)
          ..close();

    canvas.drawPath(northPath, northPaint);

    final northBorderPaint =
        Paint()
          ..color = MyApp.primaryOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawPath(northPath, northBorderPaint);

    final southPaint =
        Paint()
          ..color = const Color(0xFF87CEEB)
          ..style = PaintingStyle.fill;

    final southPath =
        ui.Path()
          ..moveTo(center.dx, center.dy + needleLength)
          ..lineTo(center.dx - 6, center.dy)
          ..lineTo(center.dx + 6, center.dy)
          ..close();

    canvas.drawPath(southPath, southPaint);

    final southBorderPaint =
        Paint()
          ..color = MyApp.accentBlue.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawPath(southPath, southBorderPaint);

    final centerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);

    final centerBorderPaint =
        Paint()
          ..color = MyApp.primaryOrange.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    canvas.drawCircle(center, 4, centerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
