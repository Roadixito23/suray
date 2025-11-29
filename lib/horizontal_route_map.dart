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
    with TickerProviderStateMixin {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<RouteStation> _stations = [];
  bool _isLoading = true;
  String? _selectedStationId;

  late AnimationController _busAnimationController;
  late Animation<double> _busAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _stationsController;

  @override
  void initState() {
    super.initState();

    // Animación cíclica del bus (ida y vuelta más rápido)
    _busAnimationController = AnimationController(
      duration: const Duration(seconds: 5), // Más rápido que antes (era 10)
      vsync: this,
    )..repeat(reverse: true); // reverse: true hace que vaya y regrese

    _busAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _busAnimationController,
      curve: Curves.easeInOut, // Suavizado en los extremos
    ));

    // Animación de pulso para elementos
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Animación de entrada para estaciones
    _stationsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _loadStations();
  }

  @override
  void dispose() {
    _busAnimationController.dispose();
    _pulseController.dispose();
    _stationsController.dispose();
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

      // Animar entrada de estaciones
      _stationsController.forward();
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Text(
                  'Cargando mapa de ruta...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
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
        // Fondo con gradiente mejorado y efectos
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MyApp.primaryNavy,
                MyApp.lightNavy,
                MyApp.primaryNavy.withOpacity(0.8),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: BackgroundPatternPainter(),
            size: Size.infinite,
          ),
        ),

        // Contenedor principal centrado y expandido
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 60,
              vertical: isMobile ? 20 : 40,
            ),
            child: Container(
              constraints: BoxConstraints(
                minHeight: screenSize.height * 0.6,
                maxHeight: screenSize.height * 0.75,
              ),
              child: Center(
                child: _buildHorizontalRoute(isMobile),
              ),
            ),
          ),
        ),

        // Panel de información de la estación seleccionada con animación
        if (_selectedStationId != null)
          _buildStationInfoPanel(isMobile),

        // Indicador de scroll mejorado para móviles
        if (isMobile)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (_pulseAnimation.value - 1.0) * 0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MyApp.primaryOrange.withOpacity(0.9),
                            MyApp.softOrange.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MyApp.primaryOrange.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.swipe_left, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Desliza horizontalmente',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalRoute(bool isMobile) {
    if (_stations.isEmpty) return const SizedBox.shrink();

    // Calcular el rango de KM (desde el mínimo al máximo)
    final int minKm = _stations.first.km;
    final int maxKm = _stations.last.km;
    final int kmRange = maxKm - minKm;

    // Calcular ancho total basado en el rango de KM (más espacio para mayor legibilidad)
    // Usamos un factor de escala para que haya suficiente espacio entre estaciones
    final double kmToPixels = isMobile ? 12.0 : 16.0;
    final double totalWidth = kmRange * kmToPixels + 120;

    return SizedBox(
      width: totalWidth,
      child: Stack(
        children: [
          // Línea principal de la ruta con efectos mejorados
          Positioned(
            top: isMobile ? 120 : 140,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(totalWidth, 6),
              painter: EnhancedRouteLinePainter(
                color: MyApp.primaryOrange,
                isMobile: isMobile,
              ),
            ),
          ),

          // Bus animado con flechas modernas
          AnimatedBuilder(
            animation: _busAnimation,
            builder: (context, child) {
              final double busPosition = _busAnimation.value * (totalWidth - 120);
              final bool goingRight = _busAnimationController.status == AnimationStatus.forward;

              return Positioned(
                top: isMobile ? 85 : 100,
                left: busPosition,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (math.sin(_busAnimation.value * math.pi * 2) * 0.05),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              MyApp.primaryOrange,
                              MyApp.softOrange,
                              MyApp.primaryOrange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: MyApp.primaryOrange.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 4,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: MyApp.primaryOrange.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Flechas modernas que simulan movimiento del bus
                            if (goingRight) ...[
                              _buildArrowIcon(isMobile, 0.6),
                              const SizedBox(width: 4),
                              _buildArrowIcon(isMobile, 0.8),
                              const SizedBox(width: 4),
                              _buildArrowIcon(isMobile, 1.0),
                            ] else ...[
                              Transform.rotate(
                                angle: math.pi,
                                child: _buildArrowIcon(isMobile, 1.0),
                              ),
                              const SizedBox(width: 4),
                              Transform.rotate(
                                angle: math.pi,
                                child: _buildArrowIcon(isMobile, 0.8),
                              ),
                              const SizedBox(width: 4),
                              Transform.rotate(
                                angle: math.pi,
                                child: _buildArrowIcon(isMobile, 0.6),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Estaciones con animación de entrada - posicionadas según KM reales
          ...List.generate(_stations.length, (index) {
            final station = _stations[index];
            // Calcular posición basada en el KM real de la estación
            final double xPosition = (station.km - minKm) * kmToPixels;
            return AnimatedBuilder(
              animation: _stationsController,
              builder: (context, child) {
                final delay = index * 0.1;
                final adjustedValue = (_stationsController.value - delay).clamp(0.0, 1.0);
                final slideValue = Curves.easeOutCubic.transform(adjustedValue);

                return Opacity(
                  opacity: slideValue,
                  child: Transform.translate(
                    offset: Offset(0, (1 - slideValue) * 30),
                    child: _buildStationMarker(station, xPosition, isMobile),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildArrowIcon(bool isMobile, double opacity) {
    return Icon(
      Icons.arrow_forward_ios_rounded,
      color: Colors.white.withOpacity(opacity),
      size: isMobile ? 16 : 20,
    );
  }

  Widget _buildStationMarker(RouteStation station, double xPosition, bool isMobile) {
    final bool isSelected = _selectedStationId == station.id;
    final double markerSize = station.isTerminal
        ? (isMobile ? 28.0 : 36.0)
        : (isMobile ? 20.0 : 26.0);

    return Positioned(
      left: xPosition,
      top: 0,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStationId = isSelected ? null : station.id;
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nombre de la estación con efecto mejorado
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Container(
                    constraints: BoxConstraints(maxWidth: isMobile ? 110 : 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 + (value * 4),
                      vertical: 4 + (value * 2),
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MyApp.primaryOrange.withOpacity(0.2 + (value * 0.3))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: MyApp.primaryOrange.withOpacity(value),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Text(
                      station.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isMobile ? 11 : 13) + (value * 2),
                        fontWeight: station.isTerminal
                            ? FontWeight.bold
                            : (isSelected ? FontWeight.w600 : FontWeight.w500),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Marcador de la estación con animación de pulso
              AnimatedBuilder(
                animation: isSelected ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  final scale = isSelected ? _pulseAnimation.value : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: station.isTerminal || isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  MyApp.primaryOrange,
                                  MyApp.softOrange,
                                ],
                              )
                            : null,
                        color: !station.isTerminal && !isSelected
                            ? Colors.white
                            : null,
                        border: Border.all(
                          color: MyApp.primaryOrange,
                          width: isSelected ? 3.5 : 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isSelected ? MyApp.primaryOrange : Colors.white)
                                .withOpacity(0.6),
                            blurRadius: isSelected ? 16 : 8,
                            spreadRadius: isSelected ? 4 : 2,
                          ),
                          if (isSelected)
                            BoxShadow(
                              color: MyApp.primaryOrange.withOpacity(0.3),
                              blurRadius: 25,
                              spreadRadius: 6,
                            ),
                        ],
                      ),
                      child: station.isTerminal
                          ? Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: isMobile ? 16 : 20,
                            )
                          : (isSelected
                              ? Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: isMobile ? 8 : 10,
                                )
                              : null),
                    ),
                  );
                },
              ),

              // Línea vertical conectora con gradiente
              Container(
                width: 3,
                height: isMobile ? 35 : 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MyApp.primaryOrange.withOpacity(0.8),
                      MyApp.primaryOrange.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // KM marker con efecto mejorado
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MyApp.primaryOrange,
                      MyApp.softOrange,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: MyApp.primaryOrange.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'KM ${station.km}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
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
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 50),
            child: Opacity(
              opacity: value,
              child: Container(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: MyApp.primaryOrange.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                MyApp.primaryOrange,
                                MyApp.softOrange,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: MyApp.primaryOrange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Km ${station.km}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            station.fullName,
                            style: TextStyle(
                              fontSize: isMobile ? 17 : 20,
                              fontWeight: FontWeight.bold,
                              color: MyApp.primaryNavy,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: MyApp.primaryNavy.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: MyApp.primaryNavy),
                            onPressed: () => setState(() => _selectedStationId = null),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    if (station.isTerminal) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: MyApp.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MyApp.primaryOrange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: MyApp.primaryOrange,
                              size: isMobile ? 18 : 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Terminal Principal',
                              style: TextStyle(
                                color: MyApp.primaryNavy,
                                fontSize: isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MyApp.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.map, color: MyApp.primaryOrange),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cómo usar el mapa',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  color: MyApp.primaryNavy,
                ),
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
                'Toca las estaciones para ver información detallada',
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
                Icons.arrow_forward_ios_rounded,
                'Las flechas animadas muestran el recorrido del bus',
                isMobile,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MyApp.primaryOrange.withOpacity(0.1),
                      MyApp.softOrange.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MyApp.primaryOrange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 22, color: MyApp.primaryOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los círculos con gradiente naranja son terminales',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: MyApp.primaryNavy,
                          fontWeight: FontWeight.w500,
                        ),
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
              backgroundColor: MyApp.primaryOrange.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MyApp.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: isMobile ? 18 : 20,
            color: MyApp.primaryOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: MyApp.primaryNavy.withOpacity(0.8),
              ),
            ),
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

/// Painter mejorado para dibujar la línea de la ruta con efectos avanzados
class EnhancedRouteLinePainter extends CustomPainter {
  final Color color;
  final bool isMobile;

  EnhancedRouteLinePainter({
    required this.color,
    required this.isMobile,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.6),
          color,
          color,
          color.withOpacity(0.6),
        ],
        stops: const [0.0, 0.2, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = isMobile ? 4 : 5
      ..strokeCap = StrokeCap.round;

    // Dibujar línea principal con gradiente
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Dibujar línea decorativa superior con efecto de brillo
    final decorativePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.4),
          color.withOpacity(0.4),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.2, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = isMobile ? 1.5 : 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height / 2 - 10),
      Offset(size.width, size.height / 2 - 10),
      decorativePaint,
    );

    // Dibujar línea decorativa inferior
    canvas.drawLine(
      Offset(0, size.height / 2 + 10),
      Offset(size.width, size.height / 2 + 10),
      decorativePaint,
    );

    // Añadir puntos decorativos a lo largo de la línea
    final dotPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 50) {
      canvas.drawCircle(
        Offset(i, size.height / 2),
        isMobile ? 2 : 2.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter para el patrón de fondo decorativo
class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Dibujar patrón de cuadrícula sutil
    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    for (double i = 0; i < size.height; i += 50) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }

    // Añadir círculos decorativos aleatorios
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Seed fijo para consistencia
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 20 + random.nextDouble() * 80;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        circlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
