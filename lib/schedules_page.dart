import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'main.dart';

class SchedulesPage extends StatefulWidget {
  final FirebaseFirestore firestore;
  final Map<String, Map<String, dynamic>> holidays;
  final String? nextAysenDeparture;
  final String? nextCoyhaiqueDeparture;
  final String? currentDayCollection;

  const SchedulesPage({
    super.key,
    required this.firestore,
    required this.holidays,
    this.nextAysenDeparture,
    this.nextCoyhaiqueDeparture,
    this.currentDayCollection,
  });

  @override
  _SchedulesPageState createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  // Nivel de zoom (0.6 = 60%, 1.1 = 110%)
  double _zoomLevel = 1.0;
  // Key para capturar screenshot
  final GlobalKey _screenshotKey = GlobalKey();
  // Indica si estamos capturando screenshot (para desactivar destacados)
  bool _isCapturingScreenshot = false;
  // Guardar zoom original para restaurar después de captura
  double _originalZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
  }

  // Método para capturar y descargar screenshot
  Future<void> _captureAndDownloadScreenshot() async {
    try {
      // Guardar zoom actual y resetear a 1.0 para captura limpia
      _originalZoomLevel = _zoomLevel;

      // Desactivar destacados y resetear zoom antes de capturar
      setState(() {
        _isCapturingScreenshot = true;
        _zoomLevel = 1.0;
      });

      // Esperar suficiente tiempo para que se actualice la UI y se carguen todos los datos
      await Future.delayed(const Duration(milliseconds: 500));

      // Mostrar indicador de carga
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Capturando imagen completa...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Esperar un poco más para asegurar que el snackbar se muestre
      await Future.delayed(const Duration(milliseconds: 300));

      // Obtener el RenderRepaintBoundary
      RenderRepaintBoundary boundary =
          _screenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // Capturar la imagen con buena calidad
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Crear nombre de archivo con fecha y hora
      final now = DateTime.now();
      final fileName =
          'horarios_suray_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.png';

      if (kIsWeb) {
        // Descargar en web
        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..click();
        html.Url.revokeObjectUrl(url);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Imagen guardada: $fileName'),
          duration: const Duration(seconds: 3),
          backgroundColor: MyApp.weekdayMint,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al capturar imagen: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: MyApp.errorColor,
        ),
      );
    } finally {
      // Reactivar destacados y restaurar zoom después de capturar
      if (mounted) {
        setState(() {
          _isCapturingScreenshot = false;
          _zoomLevel = _originalZoomLevel;
        });
      }
    }
  }

  // --- STREAMS HELPER ---
  Stream<List<String>> _timesStream(String region, String dayType) {
    // Caso especial: Sin servicio
    if (dayType == 'sinServicio') {
      return Stream.value([]);
    }

    // Caso especial: Horarios especiales de feriado
    if (dayType.startsWith('feriadoEspecial_')) {
      final parts = dayType.split('_');
      final year = parts[1];
      final feriadoKey = parts[2];

      return widget.firestore
          .collection('horarios_especiales_feriados')
          .doc(year)
          .collection(region)
          .where('feriado', isEqualTo: feriadoKey)
          .orderBy('time')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => doc.data()['time'] as String)
                    .toList(),
          );
    }

    // Caso normal: Horarios regulares
    return widget.firestore
        .collection('horarios')
        .doc(region)
        .collection(dayType)
        .orderBy('time')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc.data()['time'] as String).toList(),
        );
  }

  // --- MÉTODOS HELPER (sin cambios) ---
  bool _isDateHoliday(DateTime date) {
    final dateKey =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return widget.holidays.containsKey(dateKey) &&
        widget.holidays[dateKey]!['activo'] == true;
  }

  String _getDayCollection(DateTime date) {
    final dateKey =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Verificar si es feriado
    if (widget.holidays.containsKey(dateKey) &&
        widget.holidays[dateKey]!['activo'] == true) {
      final tipoHorario = widget.holidays[dateKey]!['tipoHorario'] ?? 'domingo';

      switch (tipoHorario) {
        case 'especial':
          return 'feriadoEspecial_${date.year}_$dateKey';
        case 'sinServicio':
          return 'sinServicio';
        case 'domingo':
        default:
          return 'domingosFeriados';
      }
    }

    if (date.weekday >= 1 && date.weekday <= 5) return 'lunesViernes';
    if (date.weekday == 6) return 'sabados';
    return 'domingosFeriados';
  }

  String _getTableIdentifier(String collection) {
    return {
          'lunesViernes': 'weekdays',
          'sabados': 'saturday',
          'domingosFeriados': 'sunday_holidays',
        }[collection] ??
        'unknown';
  }

  bool _shouldHighlightInThisTable(String tableType, String nextDeparture) {
    if (nextDeparture.toLowerCase().contains('mañana')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return tableType == _getTableIdentifier(_getDayCollection(tomorrow));
    }
    return tableType == _getTableIdentifier(widget.currentDayCollection ?? '');
  }

  @override
  Widget build(BuildContext context) {
    // Valores uniformes para todos los dispositivos
    final double baseFontSize = 14.0;
    final double chipPadding = 16.0;

    return Scaffold(
      backgroundColor: MyApp.lightGreyBackground,
      appBar: AppBar(
        backgroundColor: MyApp.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Botón de descarga
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              tooltip: 'Descargar horarios como imagen',
              onPressed: _captureAndDownloadScreenshot,
              iconSize: 24,
            ),
          ),
          // Controles de zoom en el lado derecho
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón zoom out
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 18),
                  color: MyApp.primaryNavy,
                  onPressed:
                      _zoomLevel > 0.6
                          ? () {
                            setState(() {
                              _zoomLevel = (_zoomLevel - 0.1).clamp(0.6, 1.1);
                            });
                          }
                          : null,
                  tooltip: 'Alejar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                // Indicador de zoom
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_zoomLevel * 100).round()}%',
                    style: TextStyle(
                      color: MyApp.primaryNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Botón zoom in
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 18),
                  color: MyApp.primaryNavy,
                  onPressed:
                      _zoomLevel < 1.1
                          ? () {
                            setState(() {
                              _zoomLevel = (_zoomLevel + 0.1).clamp(0.6, 1.1);
                            });
                          }
                          : null,
                  tooltip: 'Acercar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            child: RepaintBoundary(
              key: _screenshotKey,
              child: Transform.scale(
                scale: _zoomLevel,
                child: Column(
                  children: [
                    // Sección Lunes a Viernes
                    _buildDaySection(
                      'Lunes a Viernes',
                      'lunesViernes',
                      'weekdays',
                      Icons.work_rounded,
                      primaryColor: MyApp.weekdayMint,
                      darkColor: MyApp.weekdayMintDark,
                      fontSize: baseFontSize,
                      chipPadding: chipPadding,
                    ),
                    const SizedBox(height: 24),

                    // Sección Sábados
                    _buildDaySectionWithCustomIcon(
                      'Sábados',
                      'sabados',
                      'saturday',
                      _buildSaturdayIcon(),
                      primaryColor: MyApp.saturdayOrange,
                      darkColor: MyApp.saturdayOrangeDark,
                      fontSize: baseFontSize,
                      chipPadding: chipPadding,
                    ),
                    const SizedBox(height: 24),

                    // Sección Domingo o Feriado
                    _buildDaySection(
                      'Domingo o Feriado',
                      'domingosFeriados',
                      'sunday_holidays',
                      Icons.weekend,
                      primaryColor: MyApp.sundayRed,
                      darkColor: MyApp.sundayRedDark,
                      fontSize: baseFontSize,
                      chipPadding: chipPadding,
                    ),

                    // Texto informativo (solo visible durante captura)
                    if (_isCapturingScreenshot) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MyApp.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MyApp.borderColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Fecha: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: MyApp.darkTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '*Consultar los horarios en oficina',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: MyApp.lightTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget personalizado para el ícono de sábado (maletín + sofá)
  Widget _buildSaturdayIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          // Parte superior izquierda: maletín recortado
          ClipPath(
            clipper: _UpperLeftClipper(),
            child: const Icon(Icons.work, color: Colors.white, size: 24),
          ),
          // Parte inferior derecha: sofá recortado
          ClipPath(
            clipper: _LowerRightClipper(),
            child: const Icon(Icons.weekend, color: Colors.white, size: 24),
          ),
          // Línea diagonal
          CustomPaint(
            painter: _DiagonalDividerPainter(MyApp.saturdayOrange),
            size: const Size(24, 24),
          ),
        ],
      ),
    );
  }

  // Método para construir sección con ícono personalizado
  Widget _buildDaySectionWithCustomIcon(
    String dayTitle,
    String dayCollection,
    String tableType,
    Widget iconWidget, {
    required Color primaryColor,
    required Color darkColor,
    double fontSize = 14.0,
    double chipPadding = 16.0,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: MyApp.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MyApp.primaryNavy.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: MyApp.borderColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado común para el tipo de día
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, darkColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Título con ícono (centrado)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: iconWidget,
                ),
                const SizedBox(width: 12),
                Text(
                  dayTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Subtítulo "Salidas desde:"
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFB2EBF2), // Cyan pastel
            ),
            child: const Text(
              'Salidas desde:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00695C), // Verde azulado oscuro para contraste
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Dos columnas: Aysén (izquierda) y Coyhaique (derecha)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna Puerto Aysén
                Expanded(
                  child: _buildCityScheduleColumn(
                    'Puerto Aysén',
                    'aysen',
                    dayCollection,
                    tableType,
                    MyApp.primaryNavy,
                    Icons.location_on_rounded,
                    fontSize: fontSize,
                    chipPadding: chipPadding,
                  ),
                ),
                // Separador vertical
                Container(width: 2, color: MyApp.borderColor),
                // Columna Coyhaique
                Expanded(
                  child: _buildCityScheduleColumn(
                    'Coyhaique',
                    'coyhaique',
                    dayCollection,
                    tableType,
                    MyApp.accentBlue,
                    Icons.location_city_rounded,
                    fontSize: fontSize,
                    chipPadding: chipPadding,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nuevo método para construir sección por día con dos ciudades lado a lado
  Widget _buildDaySection(
    String dayTitle,
    String dayCollection,
    String tableType,
    IconData icon, {
    required Color primaryColor,
    required Color darkColor,
    double fontSize = 14.0,
    double chipPadding = 16.0,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: MyApp.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MyApp.primaryNavy.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: MyApp.borderColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado común para el tipo de día
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, darkColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Título con ícono (centrado)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  dayTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Subtítulo "Salidas desde:"
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFB2EBF2), // Cyan pastel
            ),
            child: const Text(
              'Salidas desde:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00695C), // Verde azulado oscuro para contraste
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Dos columnas: Aysén (izquierda) y Coyhaique (derecha)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna Puerto Aysén
                Expanded(
                  child: _buildCityScheduleColumn(
                    'Puerto Aysén',
                    'aysen',
                    dayCollection,
                    tableType,
                    MyApp.primaryNavy,
                    Icons.location_on_rounded,
                    fontSize: fontSize,
                    chipPadding: chipPadding,
                  ),
                ),
                // Separador vertical
                Container(width: 2, color: MyApp.borderColor),
                // Columna Coyhaique
                Expanded(
                  child: _buildCityScheduleColumn(
                    'Coyhaique',
                    'coyhaique',
                    dayCollection,
                    tableType,
                    MyApp.accentBlue,
                    Icons.location_city_rounded,
                    fontSize: fontSize,
                    chipPadding: chipPadding,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nueva columna individual de ciudad con sus horarios
  Widget _buildCityScheduleColumn(
    String cityName,
    String region,
    String dayCollection,
    String tableType,
    Color accentColor,
    IconData icon, {
    double fontSize = 14.0,
    double chipPadding = 16.0,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nombre de la ciudad
          Text(
            cityName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize + 4,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Indicador de horario especial
          if (dayCollection.startsWith('feriadoEspecial_'))
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.star, size: 16, color: Colors.purple),
                  SizedBox(width: 6),
                  Text(
                    'HORARIO ESPECIAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

          // StreamBuilder para los horarios
          StreamBuilder<List<String>>(
            stream: _timesStream(region, dayCollection),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    color: accentColor,
                    strokeWidth: 3,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MyApp.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: MyApp.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      color: MyApp.errorColor,
                      fontSize: fontSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final times = snapshot.data;
              if (times == null || times.isEmpty) {
                // Verificar si es un día sin servicio
                if (dayCollection == 'sinServicio') {
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 64,
                          color: Colors.red.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sin servicio por feriado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Mensaje normal de "No hay horarios"
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MyApp.lightTextColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No hay horarios disponibles.',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: MyApp.lightTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children:
                    times
                        .map(
                          (time) => _buildTimeChip(
                            time,
                            region,
                            tableType,
                            times,
                            fontSize: fontSize,
                            chipPadding: chipPadding,
                          ),
                        )
                        .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(
    String time,
    String region,
    String tableType,
    List<String> allTimes, {
    double fontSize = 14.0,
    double chipPadding = 16.0,
  }) {
    String? nextDeparture =
        region == 'aysen'
            ? widget.nextAysenDeparture
            : widget.nextCoyhaiqueDeparture;
    // Desactivar destacados si estamos capturando screenshot
    final isNext =
        !_isCapturingScreenshot &&
        nextDeparture != null &&
        nextDeparture.contains(time) &&
        _shouldHighlightInThisTable(tableType, nextDeparture);

    // Verificar si es la primera o última salida del día
    final isFirstOfDay = allTimes.isNotEmpty && time == allTimes.first;
    final isLastOfDay = allTimes.isNotEmpty && time == allTimes.last;

    if (isNext) {
      // Chip destacado para la próxima salida
      // Determinar el estilo según si es primera, última o salida normal
      Color primaryColor;
      Color secondaryColor;
      IconData icon;
      Color shadowColor;

      if (isFirstOfDay) {
        // Primera salida del día: amarillo con sol
        primaryColor = MyApp.saturdayOrange;
        secondaryColor = MyApp.saturdayOrangeDark;
        icon = Icons.wb_sunny;
        shadowColor = MyApp.saturdayOrange;
      } else if (isLastOfDay) {
        // Última salida del día: azul petróleo con luna
        primaryColor = MyApp.primaryNavy;
        secondaryColor = MyApp.lightNavy;
        icon = Icons.nightlight_round;
        shadowColor = MyApp.primaryNavy;
      } else {
        // Salida normal: naranja con bus
        primaryColor = MyApp.primaryOrange;
        secondaryColor = MyApp.deepOrange;
        icon = Icons.directions_bus;
        shadowColor = MyApp.primaryOrange;
      }

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: chipPadding,
          vertical: chipPadding * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.4),
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
              child: Icon(icon, color: Colors.white, size: fontSize + 2),
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
        padding: EdgeInsets.symmetric(
          horizontal: chipPadding,
          vertical: chipPadding * 0.75,
        ),
        decoration: BoxDecoration(
          color: MyApp.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MyApp.borderColor, width: 1),
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

// CustomPainter para dibujar la línea diagonal
class _DiagonalDividerPainter extends CustomPainter {
  final Color color;

  _DiagonalDividerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    // Línea diagonal de arriba-derecha a abajo-izquierda
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Clipper para la parte superior izquierda (triángulo)
class _UpperLeftClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(0, size.height)
          ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Clipper para la parte inferior derecha (triángulo)
class _LowerRightClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path =
        Path()
          ..moveTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
