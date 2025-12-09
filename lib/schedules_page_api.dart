import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'main.dart';
import 'schedule_image_generator.dart';
import 'dart:typed_data';
import 'services/api_service.dart';

class SchedulesPage extends StatefulWidget {
  final Map<String, Map<String, dynamic>> holidays;
  final String? nextAysenDeparture;
  final String? nextCoyhaiqueDeparture;
  final String? currentDayCollection;

  const SchedulesPage({
    Key? key,
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
  bool _isLoadingSchedules = false;

  @override
  void initState() {
    super.initState();
    _refreshScheduleData();
  }

  // --- MÉTODO PARA REFRESCAR DATOS DESDE LA API ---
  Future<void> _refreshScheduleData() async {
    setState(() {
      _isLoadingSchedules = true;
    });

    try {
      // Cargar horarios de Aysen
      final aysenSchedules = await ApiService.getAllHorariosByRegion('aysen');

      // Cargar horarios de Coyhaique
      final coyhaiqueSchedules = await ApiService.getAllHorariosByRegion('coyhaique');

      setState(() {
        _cachedAysenSchedules = aysenSchedules;
        _cachedCoyhaiqueSchedules = coyhaiqueSchedules;
        _isDataFresh = true;
        _isLoadingSchedules = false;
      });
    } catch (e) {
      print('Error refrescando datos: $e');
      if (mounted) {
        setState(() {
          _isLoadingSchedules = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar horarios: $e'),
            backgroundColor: MyApp.errorColor,
          ),
        );
      }
    }
  }

  // --- LÓGICA PARA DESCARGAR LA IMAGEN ---
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

      // 2. Crear el widget de imagen
      final scheduleWidget = ScheduleImageGenerator(
        aysenSchedules: _cachedAysenSchedules!,
        coyhaiqueSchedules: _cachedCoyhaiqueSchedules!,
      ).buildScheduleImage();

      // 3. Renderizar el widget a imagen
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
    } catch (e, stackTrace) {
      print('Error generando imagen: $e');
      print('StackTrace completo: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Error al generar imagen', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$e', style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: MyApp.errorColor,
            duration: const Duration(seconds: 6),
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
    final GlobalKey globalKey = GlobalKey();
    OverlayEntry? overlayEntry;

    try {
      print('Iniciando renderizado de widget a imagen...');

      final widgetToRender = RepaintBoundary(
        key: globalKey,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(1200, 800),
            devicePixelRatio: 2.0,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 1200,
                height: 800,
                color: Colors.white,
                child: widget,
              ),
            ),
          ),
        ),
      );

      final completer = Completer<Uint8List>();

      if (!mounted) {
        throw Exception('Widget no está montado');
      }

      print('Buscando overlay...');
      final overlay = Overlay.of(context, rootOverlay: true);

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -5000,
          top: -5000,
          child: widgetToRender,
        ),
      );

      print('Insertando overlay...');
      overlay.insert(overlayEntry);

      await Future.delayed(const Duration(milliseconds: 100));

      print('Esperando post-frame callback...');
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          print('Dentro del post-frame callback, esperando renderizado...');

          await Future.delayed(const Duration(milliseconds: 1000));

          print('Buscando RenderObject...');
          final RenderObject? renderObject = globalKey.currentContext?.findRenderObject();

          if (renderObject == null) {
            throw Exception('No se pudo encontrar el RenderObject');
          }

          if (renderObject is! RenderRepaintBoundary) {
            throw Exception('El RenderObject no es un RepaintBoundary');
          }

          final boundary = renderObject;
          print('RepaintBoundary encontrado correctamente');

          int attempts = 0;
          while (boundary.debugNeedsPaint && attempts < 10) {
            print('Esperando repintado (intento ${attempts + 1})...');
            await Future.delayed(const Duration(milliseconds: 300));
            attempts++;
          }

          if (boundary.debugNeedsPaint) {
            print('Advertencia: El boundary aún necesita repintado');
          }

          print('Capturando imagen...');
          final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
          print('Imagen capturada: ${image.width}x${image.height}');

          print('Convirtiendo a bytes...');
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

          if (byteData == null) {
            throw Exception('No se pudo convertir la imagen a bytes');
          }

          print('Imagen convertida exitosamente: ${byteData.lengthInBytes} bytes');

          if (!completer.isCompleted) {
            completer.complete(byteData.buffer.asUint8List());
          }
        } catch (e, stackTrace) {
          print('ERROR en callback de renderizado: $e');
          print('StackTrace del callback: $stackTrace');
          if (!completer.isCompleted) {
            completer.completeError(e, stackTrace);
          }
        }
      });

      print('Esperando resultado del completer...');
      final result = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Timeout al generar la imagen');
        },
      );

      print('Imagen generada exitosamente');
      return result;
    } catch (e, stackTrace) {
      print('ERROR GENERAL en _renderWidgetToImage: $e');
      print('StackTrace completo: $stackTrace');
      rethrow;
    } finally {
      if (overlayEntry != null) {
        try {
          print('Removiendo overlay...');
          overlayEntry.remove();
          overlayEntry = null;
        } catch (e) {
          print('Error al remover overlay: $e');
        }
      }
    }
  }

  // --- DESCARGA PARA WEB ---
  void _downloadForWeb(Uint8List pngBytes) {
    try {
      print('Iniciando descarga web...');

      final now = DateTime.now();
      final formattedDate =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';

      final blob = html.Blob([pngBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'Horarios Buses Suray ($formattedDate).png')
        ..click();
      html.Url.revokeObjectUrl(url);

      print('Descarga web completada');
    } catch (e) {
      print('Error en descarga web: $e');
      rethrow;
    }
  }

  // --- DESCARGA PARA MÓVILES ---
  Future<void> _downloadForMobile(Uint8List pngBytes) async {
    throw UnimplementedError('Descarga para móviles no implementada');
  }

  // --- MÉTODOS HELPER ---
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

    final bool isMobilePortrait = screenWidth < 600;
    final bool isTabletPortrait = screenWidth >= 600 && screenWidth < 900;
    final bool isDesktop = screenWidth >= 900;

    final bool isPortrait = screenHeight > screenWidth;

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
      body: _isLoadingSchedules
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: MyApp.primaryOrange,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cargando horarios...',
                    style: TextStyle(
                      color: MyApp.primaryNavy,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SelectionArea(
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

  Widget _buildSection(String title, String region, bool isDesktop, Color color, IconData icon,
      {double fontSize = 14.0, double chipPadding = 16.0}) {
    // Usar datos cacheados si están disponibles, sino mostrar estado de carga
    final schedules = region == 'aysen' ? _cachedAysenSchedules : _cachedCoyhaiqueSchedules;

    if (schedules == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final scheduleWidgets = [
      _buildScheduleTable('Lunes a Viernes', schedules['lunesViernes'] ?? [], region, 'weekdays',
          fontSize: fontSize, chipPadding: chipPadding),
      _buildScheduleTable('Sábados', schedules['sabados'] ?? [], region, 'saturday', fontSize: fontSize, chipPadding: chipPadding),
      _buildScheduleTable('Domingo o Feriado', schedules['domingosFeriados'] ?? [], region, 'sunday_holidays',
          fontSize: fontSize, chipPadding: chipPadding),
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
          // Header
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
                    children: scheduleWidgets
                        .map((widget) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: widget,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable(String title, List<String> times, String region, String tableType,
      {double fontSize = 14.0, double chipPadding = 16.0}) {
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
          times.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MyApp.lightTextColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('No hay horarios disponibles.', style: TextStyle(fontSize: fontSize)),
                )
              : Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: times.map((time) => _buildTimeChip(time, region, tableType, fontSize: fontSize, chipPadding: chipPadding)).toList(),
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
