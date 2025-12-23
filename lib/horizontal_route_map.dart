import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'main.dart';

class HorizontalRouteMap extends StatefulWidget {
  const HorizontalRouteMap({super.key});

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

    // Animación cíclica del bus (ida y vuelta)
    _busAnimationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _busAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _busAnimationController,
      curve: Curves.easeInOut,
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

    return Scaffold(
      backgroundColor: MyApp.primaryNavy,
      appBar: AppBar(
        title: const Text(
          'Ruta 240 - Mapa Interactivo',
          style: TextStyle(
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
          : _buildRouteMap(screenSize),
      // Barra de navegación para facilitar navegación en PC
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: MyApp.primaryNavy,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _loadStations,
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyApp.primaryOrange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showInfoDialog(context),
                icon: const Icon(Icons.info_outline),
                label: const Text('Información'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyApp.primaryOrange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Atrás'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyApp.accentBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildRouteMap(Size screenSize) {
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

        // Contenedor principal
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 24,
              ),
              child: _buildHorizontalRoute(screenSize),
            ),
          ),
        ),

        // Panel de información de la estación seleccionada
        if (_selectedStationId != null)
          _buildStationInfoPanel(),

        // Indicador de scroll (solo si hay scroll)
        if (_stations.length > 3)
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

  Widget _buildHorizontalRoute(Size screenSize) {
    if (_stations.isEmpty) return const SizedBox.shrink();

    // Calcular el rango de KM
    final int minKm = _stations.first.km;
    final int maxKm = _stations.last.km;
    final int kmRange = maxKm - minKm;

    // ============================================================
    // CÁLCULO DEL ANCHO
    // ============================================================

    // Márgenes en los bordes (izquierdo y derecho)
    final double edgeMargin = 100.0;

    // Ancho disponible de la pantalla (menos márgenes del padding exterior)
    final double screenAvailable = screenSize.width - 96;

    // Espaciado mínimo entre estaciones para evitar superposición
    final double minSpacingPerStation = 180.0;

    // Ancho mínimo necesario basado en cantidad de estaciones
    final double minRequiredWidth = (_stations.length - 1) * minSpacingPerStation + edgeMargin * 2;

    // Usar el mayor entre el ancho de pantalla y el mínimo requerido
    final double totalWidth = math.max(screenAvailable, minRequiredWidth);

    // ============================================================
    // ALTURA DEL CONTENEDOR
    // ============================================================

    // Altura disponible para el mapa (dejando espacio para AppBar y panel info)
    final double availableHeight = screenSize.height - 200;
    final double containerHeight = math.min(availableHeight, 400.0);

    // Posición Y de la línea principal (centrada verticalmente)
    final double lineY = containerHeight / 2;

    return SizedBox(
      width: totalWidth,
      height: containerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Línea principal de la ruta
          Positioned(
            top: lineY - 3,
            left: edgeMargin - 20,
            right: edgeMargin - 20,
            child: CustomPaint(
              size: Size(totalWidth - edgeMargin * 2 + 40, 6),
              painter: EnhancedRouteLinePainter(
                color: MyApp.primaryOrange,
              ),
            ),
          ),

          // Bus animado
          AnimatedBuilder(
            animation: _busAnimation,
            builder: (context, child) {
              final double busTrackWidth = totalWidth - edgeMargin * 2 - 80;
              final double busPosition = edgeMargin + _busAnimation.value * busTrackWidth;
              final bool goingRight = _busAnimationController.status == AnimationStatus.forward;

              return Positioned(
                top: lineY - 26,
                left: busPosition,
                child: Transform.scale(
                  scale: 0.95 + (math.sin(_busAnimation.value * math.pi * 2) * 0.05),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: MyApp.primaryOrange.withOpacity(0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: MyApp.primaryOrange.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (goingRight) ...[
                          _buildArrowIcon(0.5),
                          const SizedBox(width: 3),
                          _buildArrowIcon(0.75),
                          const SizedBox(width: 3),
                          _buildArrowIcon(1.0),
                        ] else ...[
                          Transform.rotate(
                            angle: math.pi,
                            child: _buildArrowIcon(1.0),
                          ),
                          const SizedBox(width: 3),
                          Transform.rotate(
                            angle: math.pi,
                            child: _buildArrowIcon(0.75),
                          ),
                          const SizedBox(width: 3),
                          Transform.rotate(
                            angle: math.pi,
                            child: _buildArrowIcon(0.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Estaciones con alternancia arriba/abajo
          ..._buildStationMarkers(
            totalWidth: totalWidth,
            edgeMargin: edgeMargin,
            lineY: lineY,
            kmRange: kmRange,
            minKm: minKm,
          ),
        ],
      ),
    );
  }

  /// Genera los marcadores de estaciones con posición alternada (arriba/abajo)
  List<Widget> _buildStationMarkers({
    required double totalWidth,
    required double edgeMargin,
    required double lineY,
    required int kmRange,
    required int minKm,
  }) {
    final double availableWidth = totalWidth - (edgeMargin * 2);

    return List.generate(_stations.length, (index) {
      final station = _stations[index];

      // Calcular posición X
      final double xPosition;
      if (_stations.length == 1) {
        xPosition = totalWidth / 2;
      } else if (kmRange > 0) {
        final double proportion = (station.km - minKm) / kmRange;
        xPosition = edgeMargin + (proportion * availableWidth);
      } else {
        xPosition = edgeMargin + (index / (_stations.length - 1)) * availableWidth;
      }

      // ============================================================
      // ALTERNANCIA: estaciones pares arriba, impares abajo
      // ============================================================
      final bool isAbove = index % 2 == 0;

      return Positioned(
        left: xPosition - 80,
        top: 0,
        bottom: 0,
        child: AnimatedBuilder(
          animation: _stationsController,
          builder: (context, child) {
            final delay = index * 0.08;
            final adjustedValue = (_stationsController.value - delay).clamp(0.0, 1.0);
            final slideValue = Curves.easeOutCubic.transform(adjustedValue);

            return Opacity(
              opacity: slideValue,
              child: Transform.translate(
                offset: Offset(0, (1 - slideValue) * (isAbove ? -20 : 20)),
                child: _buildStationContent(
                  station: station,
                  lineY: lineY,
                  isAbove: isAbove,
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildArrowIcon(double opacity) {
    return Icon(
      Icons.arrow_forward_ios_rounded,
      color: Colors.white.withOpacity(opacity),
      size: 18,
    );
  }

  /// Construye el contenido visual de una estación (alternando arriba/abajo)
  Widget _buildStationContent({
    required RouteStation station,
    required double lineY,
    required bool isAbove,
  }) {
    final bool isSelected = _selectedStationId == station.id;
    final double markerSize = station.isTerminal ? 38.0 : 28.0;

    final double connectorHeight = 40.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStationId = isSelected ? null : station.id;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 160,
          child: Stack(
            children: [
              // ============================================================
              // MARCADOR CIRCULAR (siempre en la línea)
              // ============================================================
              Positioned(
                left: 160 / 2 - markerSize / 2,
                top: lineY - markerSize / 2,
                child: AnimatedBuilder(
                  animation: isSelected ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isSelected ? _pulseAnimation.value : 1.0,
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
                              color: (station.isTerminal || isSelected
                                  ? MyApp.primaryOrange
                                  : Colors.white).withOpacity(0.5),
                              blurRadius: isSelected ? 16 : 8,
                              spreadRadius: isSelected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: station.isTerminal
                            ? Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: markerSize * 0.55,
                        )
                            : (isSelected
                            ? Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: markerSize * 0.35,
                        )
                            : null),
                      ),
                    );
                  },
                ),
              ),

              // ============================================================
              // LÍNEA CONECTORA VERTICAL
              // ============================================================
              Positioned(
                left: 160 / 2 - 1.5,
                top: isAbove
                    ? lineY - markerSize / 2 - connectorHeight
                    : lineY + markerSize / 2,
                child: Container(
                  width: 3,
                  height: connectorHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: isAbove ? Alignment.topCenter : Alignment.bottomCenter,
                      end: isAbove ? Alignment.bottomCenter : Alignment.topCenter,
                      colors: [
                        MyApp.primaryOrange.withOpacity(0.3),
                        MyApp.primaryOrange.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ============================================================
              // CONTENEDOR DE NOMBRE + KM (arriba o abajo según alternancia)
              // ============================================================
              Positioned(
                left: 0,
                right: 0,
                top: isAbove ? 0 : null,
                bottom: isAbove ? null : 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isAbove) ...[
                      SizedBox(height: lineY + markerSize / 2 + connectorHeight + 8),
                    ],

                    // Nombre de la estación
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 + (value * 4),
                            vertical: 6 + (value * 2),
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? MyApp.primaryOrange.withOpacity(0.15 + (value * 0.2))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                              color: MyApp.primaryOrange.withOpacity(0.5 + value * 0.3),
                              width: 1.5,
                            )
                                : null,
                          ),
                          child: Text(
                            station.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14 + (value * 2),
                              fontWeight: station.isTerminal
                                  ? FontWeight.bold
                                  : (isSelected ? FontWeight.w600 : FontWeight.w500),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
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

                    const SizedBox(height: 6),

                    // Badge de KM
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: MyApp.primaryOrange.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'KM ${station.km}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    if (isAbove) ...[
                      SizedBox(height: lineY - markerSize / 2 - connectorHeight - 85),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationInfoPanel() {
    final station = _stations.firstWhere(
          (s) => s.id == _selectedStationId,
      orElse: () => _stations.first,
    );

    return Positioned(
      bottom: 20,
      left: 40,
      right: 40,
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 25,
                      spreadRadius: 3,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: MyApp.primaryOrange.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 1,
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
                            gradient: LinearGradient(
                              colors: [
                                MyApp.primaryOrange,
                                MyApp.softOrange,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
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
                            style: const TextStyle(
                              fontSize: 18,
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
                            icon: const Icon(Icons.close, color: MyApp.primaryNavy, size: 20),
                            onPressed: () => setState(() => _selectedStationId = null),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    if (station.isTerminal) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: MyApp.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MyApp.primaryOrange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: MyApp.primaryOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Terminal Principal',
                              style: TextStyle(
                                color: MyApp.primaryNavy,
                                fontSize: 14,
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
            const Expanded(
              child: Text(
                'Cómo usar el mapa',
                style: TextStyle(
                  fontSize: 18,
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
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.swipe_left,
                'Desliza horizontalmente para ver toda la ruta',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.arrow_forward_ios_rounded,
                'Las flechas animadas muestran el recorrido del bus',
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
                          fontSize: 13,
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

  Widget _buildInfoRow(IconData icon, String text) {
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
            size: 20,
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
                fontSize: 14,
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

/// Painter mejorado para dibujar la línea de la ruta
class EnhancedRouteLinePainter extends CustomPainter {
  final Color color;

  EnhancedRouteLinePainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.4),
          color,
          color,
          color.withOpacity(0.4),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Línea principal
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Línea decorativa superior
    final decorativePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.35),
          color.withOpacity(0.35),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height / 2 - 12),
      Offset(size.width, size.height / 2 - 12),
      decorativePaint,
    );

    // Línea decorativa inferior
    canvas.drawLine(
      Offset(0, size.height / 2 + 12),
      Offset(size.width, size.height / 2 + 12),
      decorativePaint,
    );
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

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 30 + random.nextDouble() * 100;

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