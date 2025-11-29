import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class MetroMapRoute extends StatefulWidget {
  const MetroMapRoute({Key? key}) : super(key: key);

  @override
  State<MetroMapRoute> createState() => _MetroMapRouteState();
}

class _MetroMapRouteState extends State<MetroMapRoute> with SingleTickerProviderStateMixin {
  String? _selectedStation;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _arrowAnimation;
  final TransformationController _transformationController = TransformationController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Station> _stations = [];
  bool _isLoading = true;

  // Colores corporativos (naranja y azul)
  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color accentBlue = Color(0xFF3F51B5);
  static const Color lightBlue = Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _arrowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _loadStationsFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  /// Carga las estaciones desde Firestore
  Future<void> _loadStationsFromFirestore() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('ruta_estaciones')
          .where('activo', isEqualTo: true)  // Solo cargar estaciones activas
          .orderBy('km')
          .get();

      final stations = <Station>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        stations.add(Station(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          fullName: data['fullName'] ?? '',
          km: data['km'] ?? 0,
          side: data['side'] ?? 'center',
          isTerminal: data['isTerminal'] ?? false,
        ));
      }

      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando estaciones: $e');
      setState(() {
        _isLoading = false;
      });

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando las estaciones: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Función para calcular las posiciones de las estaciones de manera responsiva
  List<Station> _getResponsiveStations(double canvasWidth, double canvasHeight) {
    if (_stations.isEmpty) return [];

    // Determinar el rango de kilómetros
    final minKm = _stations.map((s) => s.km).reduce(math.min);
    final maxKm = _stations.map((s) => s.km).reduce(math.max);
    final kmRange = maxKm - minKm;

    // Calcular posiciones basadas en los kilómetros
    return _stations.map((station) {
      // Calcular posición Y basada en los kilómetros (normalizada 0-1)
      double yPosition = 0.04; // Por defecto al inicio
      if (kmRange > 0) {
        yPosition = 0.04 + ((station.km - minKm) / kmRange) * 0.92;
      }

      // Calcular posición X basada en el lado
      double xPosition = 0.5; // Centro por defecto
      if (station.side == 'left') {
        xPosition = 0.3;
      } else if (station.side == 'right') {
        xPosition = 0.7;
      }

      return Station(
        id: station.id,
        name: station.name,
        fullName: station.fullName,
        km: station.km,
        position: Offset(
          xPosition * canvasWidth,
          yPosition * canvasHeight,
        ),
        side: station.side,
        isTerminal: station.isTerminal,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: primaryBlue,
        appBar: AppBar(
          title: const Text(
            'Ruta 240 - Mapa Interactivo',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: primaryBlue,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
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
        ),
      );
    }

    if (_stations.isEmpty) {
      return Scaffold(
        backgroundColor: primaryBlue,
        appBar: AppBar(
          title: const Text(
            'Ruta 240 - Mapa Interactivo',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: primaryBlue,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
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
                'Configure las estaciones desde el panel administrativo',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _loadStationsFromFirestore,
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        title: Text(
          isSmallScreen ? 'Ruta 240' : 'Ruta 240 - Mapa Interactivo',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStationsFromFirestore,
            tooltip: 'Recargar estaciones',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calcular dimensiones del canvas basadas en el espacio disponible
          final double canvasWidth = math.min(constraints.maxWidth * 0.95, 600);
          final double canvasHeight = canvasWidth * 4.8; // Proporción ajustada para el mapa vertical

          // Obtener estaciones con posiciones responsivas
          final responsiveStations = _getResponsiveStations(canvasWidth, canvasHeight);

          return Stack(
            children: [
              // Fondo con imagen escalable
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/bg/background_route.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),

              // Mapa interactivo con zoom y pan para móviles
              Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: isSmallScreen ? 0.5 : 0.8,
                  maxScale: isSmallScreen ? 3.0 : 2.0,
                  boundaryMargin: EdgeInsets.all(isSmallScreen ? 100 : 200),
                  constrained: false,
                  child: Container(
                    width: canvasWidth,
                    height: canvasHeight,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: AnimatedBuilder(
                      animation: _arrowAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: ResponsiveMetroMapPainter(
                            stations: responsiveStations,
                            selectedStation: _selectedStation,
                            arrowProgress: _arrowAnimation.value,
                            canvasWidth: canvasWidth,
                            canvasHeight: canvasHeight,
                            isSmallScreen: isSmallScreen,
                          ),
                          child: Stack(
                            children: [
                              // Terminales
                              ...responsiveStations.where((s) => s.isTerminal).map((terminal) {
                                return Positioned(
                                  top: terminal.position.dy - 25,
                                  left: 0,
                                  right: 0,
                                  child: _buildTerminal(
                                    terminal.name,
                                    terminal.km,
                                    terminal.km == 0,
                                    !isSmallScreen,
                                    isSmallScreen,
                                  ),
                                );
                              }).toList(),

                              // Estaciones interactivas
                              ..._buildStationWidgets(responsiveStations, isSmallScreen),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Indicador de zoom para móviles
              if (isSmallScreen)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.pinch, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Pellizca para zoom',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // Panel de información adaptativo
              if (_selectedStation != null)
                _buildResponsiveInfoPanel(responsiveStations, isSmallScreen),

              // Botón de reset zoom para móviles
              if (isSmallScreen)
                Positioned(
                  right: 20,
                  bottom: _selectedStation != null ? 160 : 20,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: primaryOrange,
                    onPressed: () {
                      _transformationController.value = Matrix4.identity();
                    },
                    child: const Icon(Icons.zoom_out_map, color: Colors.white, size: 20),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTerminal(String text, int km, bool isStart, bool isLarge, bool isSmallScreen) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 15 : (isLarge ? 25 : 15),
          vertical: isSmallScreen ? 8 : (isLarge ? 12 : 8),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isStart
                ? [primaryBlue, primaryBlue.withOpacity(0.8)]
                : [primaryOrange, primaryOrange.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 30),
          boxShadow: [
            BoxShadow(
              color: (isStart ? primaryBlue : primaryOrange).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gps_fixed,
              color: Colors.white,
              size: isSmallScreen ? 18 : (isLarge ? 28 : 20),
            ),
            SizedBox(width: isSmallScreen ? 6 : 10),
            Column(
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 14 : (isLarge ? 20 : 14),
                  ),
                ),
                Text(
                  'Km $km',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isSmallScreen ? 10 : (isLarge ? 14 : 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStationWidgets(List<Station> stations, bool isSmallScreen) {
    final visibleStations = stations.where((station) => !station.isTerminal).toList();
    final stationSize = isSmallScreen ? 40.0 : 50.0;
    final halfSize = stationSize / 2;

    return visibleStations.map((station) {
      final isSelected = _selectedStation == station.id;
      return Positioned(
        left: station.position.dx - halfSize,
        top: station.position.dy - halfSize,
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedStation = _selectedStation == station.id ? null : station.id;
          }),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isSelected ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: stationSize,
                  height: stationSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [primaryOrange, primaryOrange.withOpacity(0.8)]
                          : [Colors.white, Colors.grey[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : (station.side == 'left' ? primaryBlue : accentBlue),
                      width: isSmallScreen ? 2 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected ? primaryOrange : primaryBlue).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${station.km}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  Widget _buildResponsiveInfoPanel(List<Station> stations, bool isSmallScreen) {
    final station = stations.firstWhere((s) => s.id == _selectedStation);

    return Positioned(
      bottom: isSmallScreen ? 10 : 20,
      left: isSmallScreen ? 10 : 20,
      right: isSmallScreen ? 10 : 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
          border: Border.all(
            color: primaryOrange.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryOrange, primaryOrange.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Km ${station.km}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    station.fullName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: primaryBlue, size: isSmallScreen ? 20 : 24),
                  onPressed: () => setState(() => _selectedStation = null),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: isSmallScreen ? 30 : 40,
                    minHeight: isSmallScreen ? 30 : 40,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 10),
            Row(
              children: [
                Icon(
                  station.side == 'left'
                      ? Icons.arrow_back
                      : station.side == 'right'
                      ? Icons.arrow_forward
                      : Icons.place,
                  color: station.side == 'left'
                      ? primaryBlue
                      : station.side == 'right'
                      ? accentBlue
                      : primaryOrange,
                  size: isSmallScreen ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  station.side == 'left'
                      ? 'Lado Izquierdo'
                      : station.side == 'right'
                      ? 'Lado Derecho'
                      : 'Terminal',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.map, color: primaryBlue, size: isSmallScreen ? 20 : 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cómo usar el mapa',
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
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
                isSmallScreen,
              ),
              const SizedBox(height: 12),
              if (isSmallScreen) ...[
                _buildInfoRow(
                  Icons.pinch,
                  'Pellizca con dos dedos para hacer zoom',
                  isSmallScreen,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.pan_tool,
                  'Arrastra para moverte por el mapa',
                  isSmallScreen,
                ),
              ] else ...[
                _buildInfoRow(
                  Icons.swipe_vertical,
                  'Desliza hacia arriba o abajo para navegar',
                  isSmallScreen,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.mouse,
                  'Usa la rueda del ratón o scroll en PC',
                  isSmallScreen,
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rotate_left, size: 20, color: primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las flechas indican el sentido del trayecto',
                        style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
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
              foregroundColor: primaryBlue,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isSmallScreen) {
    return Row(
      children: [
        Icon(icon, size: isSmallScreen ? 18 : 20, color: primaryOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
          ),
        ),
      ],
    );
  }
}

class Station {
  final String id;
  final String name;
  final String fullName;
  final int km;
  final Offset position;
  final String side;
  final bool isTerminal;

  Station({
    required this.id,
    required this.name,
    required this.fullName,
    required this.km,
    this.position = Offset.zero,
    this.side = 'center',
    this.isTerminal = false,
  });
}

class ResponsiveMetroMapPainter extends CustomPainter {
  final List<Station> stations;
  final String? selectedStation;
  final double arrowProgress;
  final double canvasWidth;
  final double canvasHeight;
  final bool isSmallScreen;

  ResponsiveMetroMapPainter({
    required this.stations,
    this.selectedStation,
    this.arrowProgress = 0.0,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isSmallScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar el marco circular con flechas
    _drawCircularRoute(canvas, size);

    // Dibujar las líneas de la ruta
    _drawRouteLines(canvas, size);

    // Dibujar nombres de estaciones (solo en pantallas grandes)
    if (!isSmallScreen) {
      _drawStationNames(canvas);
    }
  }

  void _drawCircularRoute(Canvas canvas, Size size) {
    final strokeWidth = isSmallScreen ? 1.5 : 2.0;
    final paint = Paint()
      ..color = _MetroMapRouteState.primaryBlue.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Calcular posiciones relativas
    final leftX = canvasWidth * 0.24;
    final rightX = canvasWidth * 0.76;
    final topY = canvasHeight * 0.06;
    final bottomY = canvasHeight * 0.94;

    // Dibujar el marco circular con líneas punteadas
    final leftLinePath = Path();
    leftLinePath.moveTo(leftX, topY);
    leftLinePath.lineTo(leftX, bottomY);

    final rightLinePath = Path();
    rightLinePath.moveTo(rightX, topY);
    rightLinePath.lineTo(rightX, bottomY);

    // Conexión superior
    final topPath = Path();
    topPath.moveTo(leftX, topY);
    topPath.quadraticBezierTo(canvasWidth * 0.5, topY - 20, rightX, topY);

    // Conexión inferior
    final bottomPath = Path();
    bottomPath.moveTo(leftX, bottomY);
    bottomPath.quadraticBezierTo(canvasWidth * 0.5, bottomY + 20, rightX, bottomY);

    // Dibujar líneas punteadas
    _drawDashedPath(canvas, leftLinePath, paint);
    _drawDashedPath(canvas, rightLinePath, paint);
    _drawDashedPath(canvas, topPath, paint);
    _drawDashedPath(canvas, bottomPath, paint);

    // Dibujar flechas animadas
    _drawAnimatedArrows(canvas, size);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final dashWidth = isSmallScreen ? 8.0 : 10.0;
    final dashSpace = isSmallScreen ? 4.0 : 5.0;
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          math.min(distance + dashWidth, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawAnimatedArrows(Canvas canvas, Size size) {
    final arrowPaint = Paint()
      ..color = _MetroMapRouteState.primaryOrange
      ..style = PaintingStyle.fill;

    final leftX = canvasWidth * 0.24;
    final rightX = canvasWidth * 0.76;
    final verticalRange = canvasHeight * 0.88;

    // Calcular posiciones de flechas basadas en el progreso
    final arrowPositions = [
      // Lado izquierdo (hacia abajo)
      Offset(leftX, canvasHeight * 0.12 + arrowProgress * verticalRange),
      Offset(leftX, canvasHeight * 0.12 + (verticalRange / 2) + arrowProgress * verticalRange),

      // Lado derecho (hacia arriba)
      Offset(rightX, canvasHeight * 0.94 - arrowProgress * verticalRange),
      Offset(rightX, canvasHeight * 0.94 - (verticalRange / 2) - arrowProgress * verticalRange),
    ];

    final arrowSize = isSmallScreen ? 6.0 : 8.0;

    for (final position in arrowPositions) {
      // Ajustar la posición para que circule
      final adjustedY = ((position.dy - canvasHeight * 0.06) % verticalRange) + canvasHeight * 0.06;
      final adjustedPosition = Offset(position.dx, adjustedY);

      // Determinar la dirección de la flecha
      final isLeftSide = position.dx < canvasWidth * 0.5;
      final rotation = isLeftSide ? math.pi / 2 : -math.pi / 2;

      // Dibujar flecha
      canvas.save();
      canvas.translate(adjustedPosition.dx, adjustedPosition.dy);
      canvas.rotate(rotation);

      final arrowPath = Path();
      arrowPath.moveTo(-arrowSize, -arrowSize);
      arrowPath.lineTo(arrowSize, 0);
      arrowPath.lineTo(-arrowSize, arrowSize);
      arrowPath.close();

      canvas.drawPath(arrowPath, arrowPaint);
      canvas.restore();
    }
  }

  void _drawRouteLines(Canvas canvas, Size size) {
    if (stations.isEmpty) return;

    final strokeWidth = isSmallScreen ? 4.0 : 6.0;

    final leftLinePaint = Paint()
      ..color = _MetroMapRouteState.primaryBlue
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rightLinePaint = Paint()
      ..color = _MetroMapRouteState.accentBlue
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Obtener terminales
    final terminals = stations.where((s) => s.isTerminal).toList();
    if (terminals.isEmpty) return;

    // Obtener la posición Y de los terminales
    final startTerminalY = terminals.first.position.dy;
    final endTerminalY = terminals.last.position.dy;

    // Obtener estaciones del lado izquierdo
    final leftStations = stations.where((s) => s.side == 'left' && !s.isTerminal).toList();
    if (leftStations.isNotEmpty) {
      final leftPath = Path();
      leftPath.moveTo(canvasWidth * 0.3, startTerminalY);
      for (final station in leftStations) {
        leftPath.lineTo(station.position.dx, station.position.dy);
      }
      leftPath.lineTo(canvasWidth * 0.5, endTerminalY);
      canvas.drawPath(leftPath, leftLinePaint);
    }

    // Obtener estaciones del lado derecho
    final rightStations = stations.where((s) => s.side == 'right' && !s.isTerminal).toList();
    if (rightStations.isNotEmpty) {
      final rightPath = Path();
      rightPath.moveTo(canvasWidth * 0.7, startTerminalY);
      for (final station in rightStations) {
        rightPath.lineTo(station.position.dx, station.position.dy);
      }
      rightPath.lineTo(canvasWidth * 0.5, endTerminalY);
      canvas.drawPath(rightPath, rightLinePaint);
    }
  }

  void _drawStationNames(Canvas canvas) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final station in stations.where((s) => !s.isTerminal)) {
      textPainter.text = TextSpan(
        text: station.name,
        style: TextStyle(
          color: _MetroMapRouteState.primaryBlue,
          fontSize: 10,
          fontWeight: selectedStation == station.id ? FontWeight.bold : FontWeight.normal,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.8),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      );
      textPainter.layout();

      final xOffset = station.side == 'left'
          ? station.position.dx - textPainter.width - 35
          : station.side == 'right'
          ? station.position.dx + 35
          : station.position.dx - textPainter.width / 2;

      final offset = Offset(
        xOffset,
        station.position.dy - textPainter.height / 2,
      );

      // Fondo para el texto
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offset.dx - 3,
          offset.dy - 2,
          textPainter.width + 6,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = Colors.white.withOpacity(0.95)
          ..style = PaintingStyle.fill,
      );

      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = _MetroMapRouteState.primaryOrange.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}