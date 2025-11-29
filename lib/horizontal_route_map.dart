import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'main.dart';

class HorizontalRouteMap extends StatefulWidget {
  const HorizontalRouteMap({Key? key}) : super(key: key);

  @override
  State<HorizontalRouteMap> createState() => _HorizontalRouteMapState();
}

class _HorizontalRouteMapState extends State<HorizontalRouteMap>
    with SingleTickerProviderStateMixin {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<RouteStation> _stations = [];
  bool _isLoading = true;
  String? _selectedStationId;

  late AnimationController _animationController;
  late Animation<double> _busAnimation;

  @override
  void initState() {
    super.initState();

    // Animación cíclica del bus de izquierda a derecha
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _busAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _loadStations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Carga las estaciones desde Firebase Firestore
  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('ruta_estaciones')
          .where('activo', isEqualTo: true)
          .orderBy('km')
          .get();

      final stations = <RouteStation>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        stations.add(RouteStation(
          id: doc.id,
          name: data['name'] ?? '',
          fullName: data['fullName'] ?? data['name'] ?? '',
          km: (data['km'] ?? 0).toInt(),
          isTerminal: data['isTerminal'] ?? false,
          icon: data['icon'],
        ));
      }

      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando estaciones: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando estaciones: $e'),
            backgroundColor: MyApp.errorColor,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _loadStations,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      backgroundColor: MyApp.primaryNavy,
      appBar: AppBar(
        title: Text(
          isMobile ? 'Ruta 240' : 'Ruta 240 - Mapa Interactivo',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: MyApp.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStations,
            tooltip: 'Recargar estaciones',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'Información',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _stations.isEmpty
          ? _buildEmptyState()
          : _buildRouteMap(isMobile, screenSize),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando mapa de ruta...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'No hay estaciones configuradas',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Configure las estaciones desde Firebase',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _loadStations,
            icon: const Icon(Icons.refresh),
            label: const Text('Recargar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MyApp.primaryOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap(bool isMobile, Size screenSize) {
    return Stack(
      children: [
        // Fondo con gradiente
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MyApp.primaryNavy,
                MyApp.lightNavy,
              ],
            ),
          ),
        ),

        // Contenedor principal con scroll horizontal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40,
            vertical: isMobile ? 40 : 60,
          ),
          child: SizedBox(
            height: screenSize.height - (isMobile ? 200 : 250),
            child: _buildHorizontalRoute(isMobile),
          ),
        ),

        // Panel de información de la estación seleccionada
        if (_selectedStationId != null)
          _buildStationInfoPanel(isMobile),

        // Indicador de scroll para móviles
        if (isMobile)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.swipe_left, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Desliza horizontalmente',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalRoute(bool isMobile) {
    if (_stations.isEmpty) return const SizedBox.shrink();

    // Calcular el ancho total basado en el número de estaciones
    final double stationSpacing = isMobile ? 120.0 : 150.0;
    final double totalWidth = (_stations.length - 1) * stationSpacing + 100;

    return SizedBox(
      width: totalWidth,
      child: Stack(
        children: [
          // Línea principal de la ruta
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(totalWidth, 4),
              painter: RouteLinePainter(
                color: MyApp.primaryOrange,
                isMobile: isMobile,
              ),
            ),
          ),

          // Bus animado
          AnimatedBuilder(
            animation: _busAnimation,
            builder: (context, child) {
              final double busPosition = _busAnimation.value * (totalWidth - 100);
              return Positioned(
                top: 70,
                left: busPosition,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MyApp.primaryOrange,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: MyApp.primaryOrange.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                ),
              );
            },
          ),

          // Estaciones
          ...List.generate(_stations.length, (index) {
            final station = _stations[index];
            final xPosition = index * stationSpacing;
            return _buildStationMarker(station, xPosition, isMobile);
          }),
        ],
      ),
    );
  }

  Widget _buildStationMarker(RouteStation station, double xPosition, bool isMobile) {
    final bool isSelected = _selectedStationId == station.id;
    final double markerSize = station.isTerminal
        ? (isMobile ? 24.0 : 30.0)
        : (isMobile ? 18.0 : 22.0);

    return Positioned(
      left: xPosition,
      top: 0,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStationId = isSelected ? null : station.id;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nombre de la estación
            Container(
              constraints: BoxConstraints(maxWidth: isMobile ? 100 : 130),
              child: Text(
                station.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: station.isTerminal ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),

            // Marcador de la estación
            Container(
              width: markerSize,
              height: markerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: station.isTerminal
                    ? MyApp.primaryOrange
                    : (isSelected ? MyApp.softOrange : Colors.white),
                border: Border.all(
                  color: MyApp.primaryOrange,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? MyApp.primaryOrange : Colors.white)
                        .withOpacity(0.5),
                    blurRadius: isSelected ? 12 : 6,
                    spreadRadius: isSelected ? 2 : 1,
                  ),
                ],
              ),
              child: station.isTerminal
                  ? const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 16,
              )
                  : null,
            ),

            // Línea vertical conectora
            Container(
              width: 2,
              height: 30,
              color: MyApp.primaryOrange.withOpacity(0.5),
            ),

            // KM marker
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 6 : 8,
                vertical: isMobile ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: MyApp.primaryOrange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: MyApp.primaryOrange.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'KM ${station.km}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoPanel(bool isMobile) {
    final station = _stations.firstWhere((s) => s.id == _selectedStationId);

    return Positioned(
      bottom: 20,
      left: isMobile ? 10 : 20,
      right: isMobile ? 10 : 20,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MyApp.primaryOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Km ${station.km}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    station.fullName,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: MyApp.primaryNavy,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: MyApp.primaryNavy),
                  onPressed: () => setState(() => _selectedStationId = null),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            if (station.isTerminal) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: MyApp.primaryOrange,
                    size: isMobile ? 16 : 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Terminal',
                    style: TextStyle(
                      color: MyApp.lightTextColor,
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.map, color: MyApp.primaryNavy),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cómo usar el mapa',
                style: TextStyle(fontSize: isMobile ? 16 : 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                Icons.touch_app,
                'Toca las estaciones para ver información',
                isMobile,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.swipe_left,
                'Desliza horizontalmente para ver toda la ruta',
                isMobile,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.directions_bus,
                'El bus animado muestra el recorrido',
                isMobile,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MyApp.lightGreyBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 20, color: MyApp.primaryOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los círculos naranjas son terminales',
                        style: TextStyle(fontSize: isMobile ? 12 : 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: MyApp.primaryNavy,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isMobile) {
    return Row(
      children: [
        Icon(icon, size: isMobile ? 18 : 20, color: MyApp.primaryOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
      ],
    );
  }
}

/// Modelo de datos para una estación de ruta
class RouteStation {
  final String id;
  final String name;
  final String fullName;
  final int km;
  final bool isTerminal;
  final String? icon;

  RouteStation({
    required this.id,
    required this.name,
    required this.fullName,
    required this.km,
    this.isTerminal = false,
    this.icon,
  });
}

/// Painter para dibujar la línea de la ruta
class RouteLinePainter extends CustomPainter {
  final Color color;
  final bool isMobile;

  RouteLinePainter({
    required this.color,
    required this.isMobile,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = isMobile ? 3 : 4
      ..strokeCap = StrokeCap.round;

    // Dibujar línea principal
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Dibujar línea decorativa superior
    final decorativePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = isMobile ? 1 : 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height / 2 - 8),
      Offset(size.width, size.height / 2 - 8),
      decorativePaint,
    );

    // Dibujar línea decorativa inferior
    canvas.drawLine(
      Offset(0, size.height / 2 + 8),
      Offset(size.width, size.height / 2 + 8),
      decorativePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}