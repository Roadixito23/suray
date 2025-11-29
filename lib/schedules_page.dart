import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'main.dart';
import 'schedule_image_generator.dart';
import 'dart:typed_data';

class SchedulesPage extends StatefulWidget {
  final FirebaseFirestore firestore;
  final Map<String, Map<String, dynamic>> holidays;
  final String? nextAysenDeparture;
  final String? nextCoyhaiqueDeparture;
  final String? currentDayCollection;

  const SchedulesPage({
    Key? key,
    required this.firestore,
    required this.holidays,
    this.nextAysenDeparture,
    this.nextCoyhaiqueDeparture,
    this.currentDayCollection,
  }) : super(key: key);

  @override
  _SchedulesPageState createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  bool _isLoadingImage = false;

  // Cache para los horarios actuales
  Map<String, List<String>>? _cachedAysenSchedules;
  Map<String, List<String>>? _cachedCoyhaiqueSchedules;
  bool _isDataFresh = false;

  @override
  void initState() {
    super.initState();
    _refreshScheduleData();
  }

  // --- MÉTODO PARA REFRESCAR DATOS ---
  Future<void> _refreshScheduleData() async {
    try {
      // Forzar recarga de datos desde Firebase
      final aysenSchedules = {
        'lunesViernes': await _timesStream('aysen', 'lunesViernes').first,
        'sabados': await _timesStream('aysen', 'sabados').first,
        'domingosFeriados': await _timesStream('aysen', 'domingosFeriados').first,
      };
      final coyhaiqueSchedules = {
        'lunesViernes': await _timesStream('coyhaique', 'lunesViernes').first,
        'sabados': await _timesStream('coyhaique', 'sabados').first,
        'domingosFeriados': await _timesStream('coyhaique', 'domingosFeriados').first,
      };

      setState(() {
        _cachedAysenSchedules = aysenSchedules;
        _cachedCoyhaiqueSchedules = coyhaiqueSchedules;
        _isDataFresh = true;
      });
    } catch (e) {
      print('Error refrescando datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar horarios: $e'),
            backgroundColor: MyApp.errorColor,
          ),
        );
      }
    }
  }

  // --- STREAMS HELPER ---
  Stream<List<String>> _timesStream(String region, String dayType) {
    return widget.firestore
        .collection('horarios')
        .doc(region)
        .collection(dayType)
        .orderBy('time')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()['time'] as String).toList());
  }

  // --- NUEVA LÓGICA PARA DESCARGAR LA IMAGEN (SIN OFFSTAGE) ---
  Future<void> _downloadSchedules() async {
    setState(() {
      _isLoadingImage = true;
    });

    try {
      // 1. Refrescar datos antes de generar imagen
      await _refreshScheduleData();

      if (!_isDataFresh || _cachedAysenSchedules == null || _cachedCoyhaiqueSchedules == null) {
        throw Exception('No se pudieron cargar los horarios actualizados');
      }

      // 2. Crear el widget de imagen dinámicamente
      final scheduleWidget = ScheduleImageGenerator(
        aysenSchedules: _cachedAysenSchedules!,
        coyhaiqueSchedules: _cachedCoyhaiqueSchedules!,
      ).buildScheduleImage();

      // 3. Renderizar el widget a imagen usando un método alternativo
      final pngBytes = await _renderWidgetToImage(scheduleWidget);

      // 4. Descargar según la plataforma
      if (kIsWeb) {
        _downloadForWeb(pngBytes);
      } else {
        await _downloadForMobile(pngBytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('¡Horarios descargados exitosamente!'),
              ],
            ),
            backgroundColor: MyApp.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      print('Error generando imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar imagen: $e'),
            backgroundColor: MyApp.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  // --- MÉTODO PARA RENDERIZAR WIDGET A IMAGEN ---
  Future<Uint8List> _renderWidgetToImage(Widget widget) async {
    // Crear un GlobalKey para el RepaintBoundary
    final globalKey = GlobalKey();
    
    // Crear un widget temporal que muestre nuestro contenido
    final widgetToRender = RepaintBoundary(
      key: globalKey,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(1200, 800), // Cambiado a horizontal: ancho > alto
          devicePixelRatio: 2.0,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: Container(
              width: 1200, // Ancho mayor para formato horizontal
              height: 800,  // Alto menor para formato horizontal
              color: Colors.white,
              child: widget,
            ),
          ),
        ),
      ),
    );

    // Mostrar el widget en un overlay temporal
    late OverlayEntry overlayEntry;
    final completer = Completer<Uint8List>();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -2000, // Fuera de pantalla
        top: -2000,
        child: widgetToRender,
      ),
    );

    // Agregar el overlay
    Overlay.of(context).insert(overlayEntry);

    // Esperar a que se renderice
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Pequeña pausa para asegurar renderizado completo
        await Future.delayed(const Duration(milliseconds: 500));
        
        final boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          throw Exception('No se pudo obtener el boundary para renderizar');
        }

        // Verificar que no necesite repintado
        if (boundary.debugNeedsPaint) {
          await Future.delayed(const Duration(milliseconds: 300));
        }

        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData == null) {
          throw Exception('No se pudo convertir la imagen a bytes');
        }

        completer.complete(byteData.buffer.asUint8List());
      } catch (e) {
        completer.completeError(e);
      } finally {
        // Remover el overlay
        overlayEntry.remove();
      }
    });

    return completer.future;
  }

  // --- DESCARGA PARA WEB ---
  void _downloadForWeb(Uint8List pngBytes) {
    // Formatear fecha como ddmmaa
    final now = DateTime.now();
    final formattedDate = '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';
    
    final blob = html.Blob([pngBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'Horarios Buses Suray ($formattedDate).png')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // --- DESCARGA PARA MÓVILES ---
  Future<void> _downloadForMobile(Uint8List pngBytes) async {
    throw UnimplementedError('Descarga para móviles no implementada en esta versión web');
  }

  // --- MÉTODOS HELPER (sin cambios) ---
  bool _isDateHoliday(DateTime date) {
    final dateKey = "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return widget.holidays.containsKey(dateKey) && widget.holidays[dateKey]!['activo'] == true;
  }

  String _getDayCollection(DateTime date) {
    if (_isDateHoliday(date)) return 'domingosFeriados';
    if (date.weekday >= 1 && date.weekday <= 5) return 'lunesViernes';
    if (date.weekday == 6) return 'sabados';
    return 'domingosFeriados';
  }

  String _getTableIdentifier(String collection) {
    return {'lunesViernes': 'weekdays', 'sabados': 'saturday', 'domingosFeriados': 'sunday_holidays'}[collection] ?? 'unknown';
  }

  bool _shouldHighlightInThisTable(String tableType, String nextDeparture) {
    if (nextDeparture.contains('(mañana)')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return tableType == _getTableIdentifier(_getDayCollection(tomorrow));
    }
    return tableType == _getTableIdentifier(widget.currentDayCollection ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Detección mejorada de dispositivos móviles
    final bool isMobilePortrait = screenWidth < 600;
    final bool isTabletPortrait = screenWidth >= 600 && screenWidth < 900;
    final bool isDesktop = screenWidth >= 900;

    // Detectar orientación
    final bool isPortrait = screenHeight > screenWidth;

    // Calcular el tamaño de fuente dinámicamente para móviles
    final double baseFontSize = isMobilePortrait ? 13.0 : 14.0;
    final double chipPadding = isMobilePortrait ? 10.0 : 16.0;

    return Scaffold(
      backgroundColor: MyApp.lightGreyBackground,
      appBar: AppBar(
        title: const Text('Horarios Completos'),
        backgroundColor: MyApp.primaryNavy,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          // Botón de refrescar
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshScheduleData,
              tooltip: 'Actualizar horarios',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Botón principal de descarga
                ElevatedButton.icon(
                  onPressed: _isLoadingImage ? null : _downloadSchedules,
                  icon: _isLoadingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(_isLoadingImage ? 'Generando imagen...' : 'Descargar Horarios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyApp.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                // Indicador de estado de datos
                if (!_isDataFresh)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Actualizando datos...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SelectionArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MyApp.primaryNavy.withOpacity(0.05),
                MyApp.lightGreyBackground,
                MyApp.surfaceWhite,
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSection(
                  'Salidas desde Puerto Aysén',
                  'aysen',
                  isDesktop,
                  MyApp.primaryNavy,
                  Icons.location_city_rounded,
                  fontSize: baseFontSize,
                  chipPadding: chipPadding,
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Salidas desde Coyhaique',
                  'coyhaique',
                  isDesktop,
                  MyApp.accentBlue,
                  Icons.location_city_rounded,
                  fontSize: baseFontSize,
                  chipPadding: chipPadding,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String region, bool isDesktop, Color color, IconData icon, {double fontSize = 14.0, double chipPadding = 16.0}) {
    final scheduleWidgets = [
      _buildScheduleTable('Lunes a Viernes', _timesStream(region, 'lunesViernes'), region, 'weekdays', fontSize: fontSize, chipPadding: chipPadding),
      _buildScheduleTable('Sábados', _timesStream(region, 'sabados'), region, 'saturday', fontSize: fontSize, chipPadding: chipPadding),
      _buildScheduleTable('Domingos y Feriados', _timesStream(region, 'domingosFeriados'), region, 'sunday_holidays', fontSize: fontSize, chipPadding: chipPadding),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MyApp.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: MyApp.borderColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con gradiente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: scheduleWidgets[0]),
                      const SizedBox(width: 20),
                      Expanded(child: scheduleWidgets[1]),
                      const SizedBox(width: 20),
                      Expanded(child: scheduleWidgets[2]),
                    ],
                  )
                : Column(
                    children: scheduleWidgets.map((widget) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: widget,
                        ),
                    ).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable(String title, Stream<List<String>> stream, String region, String tableType, {double fontSize = 14.0, double chipPadding = 16.0}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MyApp.lightGreyBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MyApp.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyApp.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForScheduleType(title),
                  color: MyApp.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MyApp.primaryNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize + 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<String>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(
                      color: MyApp.primaryOrange,
                      strokeWidth: 3,
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MyApp.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MyApp.errorColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: MyApp.errorColor, fontSize: fontSize),
                  ),
                );
              }
              final times = snapshot.data;
              if (times == null || times.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MyApp.lightTextColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('No hay horarios disponibles.', style: TextStyle(fontSize: fontSize)),
                );
              }

              return Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: times.map((time) => _buildTimeChip(time, region, tableType, fontSize: fontSize, chipPadding: chipPadding)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForScheduleType(String title) {
    if (title.contains('Lunes')) return Icons.work_rounded;
    if (title.contains('Sábado')) return Icons.weekend_rounded;
    if (title.contains('Domingo')) return Icons.weekend_rounded;
    return Icons.schedule_rounded;
  }

  Widget _buildTimeChip(String time, String region, String tableType, {double fontSize = 14.0, double chipPadding = 16.0}) {
    String? nextDeparture = region == 'aysen' ? widget.nextAysenDeparture : widget.nextCoyhaiqueDeparture;
    final isNext = nextDeparture != null && nextDeparture.contains(time) && _shouldHighlightInThisTable(tableType, nextDeparture);
    final isTomorrow = nextDeparture?.contains('(mañana)') ?? false;

    if (isNext) {
      // Chip destacado para la próxima salida
      return Container(
        padding: EdgeInsets.symmetric(horizontal: chipPadding, vertical: chipPadding * 0.75),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [MyApp.primaryOrange, MyApp.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: MyApp.primaryOrange.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTomorrow ? Icons.nightlight_round : Icons.directions_bus,
                color: Colors.white,
                size: fontSize + 2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize + 1,
              ),
            ),
          ],
        ),
      );
    } else {
      // Chip normal para los demás horarios
      return Container(
        padding: EdgeInsets.symmetric(horizontal: chipPadding, vertical: chipPadding * 0.75),
        decoration: BoxDecoration(
          color: MyApp.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MyApp.borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: MyApp.primaryNavy.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: MyApp.darkTextColor,
            fontSize: fontSize,
          ),
        ),
      );
    }
  }
}