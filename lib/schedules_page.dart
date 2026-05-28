import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'main.dart';
import 'floating_notification.dart';

// ─── Tema interno ─────────────────────────────────────────────────────────────
class _ST {
  final Color bg;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;
  final Color chipBg;
  final Color chipBorder;
  final Color appBarBg;
  const _ST({
    required this.bg,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.chipBg,
    required this.chipBorder,
    required this.appBarBg,
  });
}

// ─── Definición de sección ────────────────────────────────────────────────────
class _SectionDef {
  final String title;
  final String collection;
  final String tableType;
  final IconData? icon;
  final Widget? iconWidget;
  final Color primaryColor;
  final Color darkColor;
  final Color? subtitleBg;
  final Color? subtitleText;
  const _SectionDef({
    required this.title,
    required this.collection,
    required this.tableType,
    this.icon,
    this.iconWidget,
    required this.primaryColor,
    required this.darkColor,
    this.subtitleBg,
    this.subtitleText,
  });
}

// ─── Widget principal ─────────────────────────────────────────────────────────
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
  bool get _isDark => darkModeNotifier.value;
  double _zoomLevel = 1.0;
  final GlobalKey _screenshotKey = GlobalKey();
  bool _isCapturingScreenshot = false;
  double _originalZoomLevel = 1.0;

  void _onDarkModeChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    darkModeNotifier.addListener(_onDarkModeChanged);
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onDarkModeChanged);
    super.dispose();
  }

  // ── Tema ────────────────────────────────────────────────────────────────────
  _ST get _theme =>
      _isDark
          ? _ST(
            bg: const Color(0xFF0A1628),
            cardBg: const Color(0xFF112240),
            textPrimary: Colors.white,
            textSecondary: const Color(0xFF8899AA),
            border: Colors.white.withOpacity(0.1),
            divider: Colors.white.withOpacity(0.12),
            chipBg: const Color(0xFF1A2F4A),
            chipBorder: Colors.white.withOpacity(0.18),
            appBarBg: const Color(0xFF0A1628),
          )
          : _ST(
            bg: MyApp.lightGreyBackground,
            cardBg: MyApp.surfaceWhite,
            textPrimary: MyApp.darkTextColor,
            textSecondary: MyApp.lightTextColor,
            border: MyApp.borderColor.withOpacity(0.5),
            divider: MyApp.borderColor,
            chipBg: MyApp.surfaceWhite,
            chipBorder: MyApp.borderColor,
            appBarBg: MyApp.primaryNavy,
          );

  // ── Screenshot ───────────────────────────────────────────────────────────────
  Future<void> _captureAndDownloadScreenshot() async {
    try {
      _originalZoomLevel = _zoomLevel;
      setState(() {
        _isCapturingScreenshot = true;
        _zoomLevel = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      FloatingNotification.show(
        context,
        message: 'Capturando imagen completa...',
        type: NotificationType.info,
        duration: const Duration(seconds: 2),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      final boundary =
          _screenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final now = DateTime.now();
      final fileName =
          'horarios_suray_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.png';
      if (kIsWeb) {
        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      }
      if (!mounted) return;
      FloatingNotification.show(
        context,
        message: 'Imagen guardada: $fileName',
        type: NotificationType.success,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (!mounted) return;
      FloatingNotification.show(
        context,
        message: 'Error al capturar imagen. Inténtalo nuevamente',
        type: NotificationType.error,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingScreenshot = false;
          _zoomLevel = _originalZoomLevel;
        });
      }
    }
  }

  // ── Streams ──────────────────────────────────────────────────────────────────
  Stream<List<String>> _timesStream(String region, String dayType) {
    if (dayType == 'sinServicio') return Stream.value([]);
    if (dayType.startsWith('feriadoEspecial_')) {
      final parts = dayType.split('_');
      return widget.firestore
          .collection('horarios_especiales_feriados')
          .doc(parts[1])
          .collection(region)
          .where('feriado', isEqualTo: parts[2])
          .orderBy('time')
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()['time'] as String).toList());
    }
    return widget.firestore
        .collection('horarios')
        .doc(region)
        .collection(dayType)
        .orderBy('time')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['time'] as String).toList());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _getDayCollection(DateTime date) {
    final key =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (widget.holidays.containsKey(key) &&
        widget.holidays[key]!['activo'] == true) {
      switch (widget.holidays[key]!['tipoHorario'] ?? 'domingo') {
        case 'especial':
          return 'feriadoEspecial_${date.year}_$key';
        case 'sinServicio':
          return 'sinServicio';
        default:
          return 'domingosFeriados';
      }
    }
    if (date.weekday >= 1 && date.weekday <= 5) return 'lunesViernes';
    if (date.weekday == 6) return 'sabados';
    return 'domingosFeriados';
  }

  String _getTableIdentifier(String col) =>
      {
        'lunesViernes': 'weekdays',
        'sabados': 'saturday',
        'domingosFeriados': 'sunday_holidays',
      }[col] ??
      'unknown';

  bool _shouldHighlightInThisTable(String tableType, String nextDeparture) {
    if (nextDeparture.toLowerCase().contains('mañana')) {
      return tableType ==
          _getTableIdentifier(
            _getDayCollection(DateTime.now().add(const Duration(days: 1))),
          );
    }
    return tableType == _getTableIdentifier(widget.currentDayCollection ?? '');
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    const double fontSize = 14.0;
    const double chipPad = 14.0;

    final sections = [
      _SectionDef(
        title: 'Lunes a Viernes',
        collection: 'lunesViernes',
        tableType: 'weekdays',
        icon: Icons.work_rounded,
        primaryColor: MyApp.weekdayMint,
        darkColor: MyApp.weekdayMintDark,
        subtitleBg: const Color(0xFFB2EBF2),
        subtitleText: const Color(0xFF00695C),
      ),
      _SectionDef(
        title: 'Sábados',
        collection: 'sabados',
        tableType: 'saturday',
        iconWidget: _buildSaturdayIcon(),
        primaryColor: MyApp.saturdayOrange,
        darkColor: MyApp.saturdayOrangeDark,
        subtitleBg: const Color(0xFFFFF9C4),
        subtitleText: const Color(0xFFF57F17),
      ),
      _SectionDef(
        title: 'Domingo o Feriado',
        collection: 'domingosFeriados',
        tableType: 'sunday_holidays',
        icon: Icons.weekend,
        primaryColor: MyApp.sundayRed,
        darkColor: MyApp.sundayRedDark,
        subtitleBg: const Color(0xFFFFCDD2),
        subtitleText: const Color(0xFFC62828),
      ),
    ];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _buildAppBar(t),
      body: SelectionArea(
        child: Container(
          color: t.bg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              key: _screenshotKey,
              child: Transform.scale(
                scale: _zoomLevel,
                alignment: Alignment.topCenter,
                child:
                    isLandscape
                        ? _buildLandscapeLayout(sections, t, fontSize, chipPad)
                        : _buildPortraitLayout(sections, t, fontSize, chipPad),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(_ST t) {
    return AppBar(
      backgroundColor: t.appBarBg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Horarios',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        // Toggle modo claro/oscuro
        Tooltip(
          message: _isDark ? 'Modo claro' : 'Modo oscuro',
          child: IconButton(
            icon: Icon(
              _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              final newVal = !darkModeNotifier.value;
              darkModeNotifier.value = newVal;
              saveDarkMode(newVal);
            },
          ),
        ),
        // Descargar imagen
        IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          tooltip: 'Descargar como imagen',
          onPressed: _captureAndDownloadScreenshot,
        ),
        // Zoom
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomBtn(Icons.remove, _zoomLevel > 0.6, () {
                setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.6, 1.5));
              }),
              Text(
                '${(_zoomLevel * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              _zoomBtn(Icons.add, _zoomLevel < 1.5, () {
                setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.6, 1.5));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoomBtn(IconData icon, bool enabled, VoidCallback fn) =>
      GestureDetector(
        onTap: enabled ? fn : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white38,
            size: 18,
          ),
        ),
      );

  // ── Portrait: tarjetas apiladas ──────────────────────────────────────────────
  Widget _buildPortraitLayout(
    List<_SectionDef> sections,
    _ST t,
    double fontSize,
    double chipPad,
  ) {
    return Column(
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _buildDayCard(sections[i], t, fontSize, chipPad, false),
        ],
        if (_isCapturingScreenshot) _buildCaptureFooter(t),
      ],
    );
  }

  // ── Landscape: 3 tarjetas en fila ────────────────────────────────────────────
  Widget _buildLandscapeLayout(
    List<_SectionDef> sections,
    _ST t,
    double fontSize,
    double chipPad,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: _buildDayCard(sections[i], t, fontSize, chipPad, true),
          ),
        ],
      ],
    );
  }

  // ── Tarjeta por tipo de día ───────────────────────────────────────────────────
  Widget _buildDayCard(
    _SectionDef s,
    _ST t,
    double fontSize,
    double chipPad,
    bool isLandscape,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: t.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado coloreado
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [s.primaryColor, s.darkColor],
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
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      s.iconWidget ??
                      Icon(s.icon!, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    s.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Fila "Salidas desde:"
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            decoration: BoxDecoration(
              color:
                  _isDark
                      ? Colors.white.withOpacity(0.06)
                      : (s.subtitleBg ?? const Color(0xFFB2EBF2)),
            ),
            child: Text(
              'Salidas desde:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    _isDark
                        ? Colors.white70
                        : (s.subtitleText ?? const Color(0xFF00695C)),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Dos columnas: Aysén | Coyhaique
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildCityCol(
                    'Puerto Aysén',
                    'aysen',
                    s.collection,
                    s.tableType,
                    MyApp.primaryNavy,
                    Icons.location_on_rounded,
                    t,
                    fontSize,
                    chipPad,
                    isLandscape,
                  ),
                ),
                Container(width: 1, color: t.divider),
                Expanded(
                  child: _buildCityCol(
                    'Coyhaique',
                    'coyhaique',
                    s.collection,
                    s.tableType,
                    MyApp.accentBlue,
                    Icons.location_city_rounded,
                    t,
                    fontSize,
                    chipPad,
                    isLandscape,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Columna de ciudad ────────────────────────────────────────────────────────
  Widget _buildCityCol(
    String cityName,
    String region,
    String dayCollection,
    String tableType,
    Color accentColor,
    IconData icon,
    _ST t,
    double fontSize,
    double chipPad,
    bool isLandscape,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nombre ciudad
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(_isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: _isDark ? Colors.white : accentColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  cityName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize + 2,
                    color: _isDark ? Colors.white : accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badge feriado especial
          if (dayCollection.startsWith('feriadoEspecial_'))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.purple.withOpacity(0.6)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 13, color: Colors.purple),
                  SizedBox(width: 4),
                  Text(
                    'HORARIO ESPECIAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

          // Horarios
          StreamBuilder<List<String>>(
            stream: _timesStream(region, dayCollection),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: accentColor,
                    strokeWidth: 3,
                  ),
                );
              }
              if (snap.hasError) {
                return Text(
                  'Error al cargar',
                  style: TextStyle(color: MyApp.errorColor, fontSize: fontSize),
                  textAlign: TextAlign.center,
                );
              }
              final times = snap.data;
              if (times == null || times.isEmpty) {
                if (dayCollection == 'sinServicio') {
                  return Column(
                    children: [
                      Icon(
                        Icons.do_not_disturb_on_rounded,
                        size: 48,
                        color: Colors.red.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sin servicio\npor feriado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }
                return Text(
                  'Sin horarios',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: t.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                );
              }
              return isLandscape
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        times
                            .map(
                              (time) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: _buildTimeChip(
                                  time,
                                  region,
                                  tableType,
                                  times,
                                  t: t,
                                  fontSize: fontSize,
                                  chipPad: chipPad,
                                ),
                              ),
                            )
                            .toList(),
                  )
                  : Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.center,
                    children:
                        times
                            .map(
                              (time) => _buildTimeChip(
                                time,
                                region,
                                tableType,
                                times,
                                t: t,
                                fontSize: fontSize,
                                chipPad: chipPad,
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

  // ── Chip de horario ──────────────────────────────────────────────────────────
  Widget _buildTimeChip(
    String time,
    String region,
    String tableType,
    List<String> allTimes, {
    required _ST t,
    double fontSize = 14.0,
    double chipPad = 14.0,
  }) {
    final nextDep =
        region == 'aysen'
            ? widget.nextAysenDeparture
            : widget.nextCoyhaiqueDeparture;
    final isNext =
        !_isCapturingScreenshot &&
        nextDep != null &&
        nextDep.contains(time) &&
        _shouldHighlightInThisTable(tableType, nextDep);
    final isFirst = allTimes.isNotEmpty && time == allTimes.first;
    final isLast = allTimes.isNotEmpty && time == allTimes.last;

    if (isNext) {
      final Color c1, c2;
      final IconData ic;
      if (isFirst) {
        c1 = MyApp.saturdayOrange;
        c2 = MyApp.saturdayOrangeDark;
        ic = Icons.wb_sunny;
      } else if (isLast) {
        c1 = MyApp.primaryNavy;
        c2 = MyApp.lightNavy;
        ic = Icons.nightlight_round;
      } else {
        c1 = MyApp.primaryOrange;
        c2 = MyApp.deepOrange;
        ic = Icons.directions_bus;
      }
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: chipPad,
          vertical: chipPad * 0.65,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: c1.withOpacity(0.4),
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
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(ic, color: Colors.white, size: fontSize + 1),
            ),
            const SizedBox(width: 7),
            Text(
              time,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: chipPad,
        vertical: chipPad * 0.65,
      ),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.chipBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        time,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
          fontSize: fontSize,
        ),
      ),
    );
  }

  // ── Ícono sábado ─────────────────────────────────────────────────────────────
  Widget _buildSaturdayIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        children: [
          ClipPath(
            clipper: _UpperLeftClipper(),
            child: const Icon(Icons.work, color: Colors.white, size: 22),
          ),
          ClipPath(
            clipper: _LowerRightClipper(),
            child: const Icon(Icons.weekend, color: Colors.white, size: 22),
          ),
          CustomPaint(
            painter: _DiagonalDividerPainter(MyApp.saturdayOrange),
            size: const Size(22, 22),
          ),
        ],
      ),
    );
  }

  // ── Footer al capturar ────────────────────────────────────────────────────────
  Widget _buildCaptureFooter(_ST t) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Column(
          children: [
            Image.asset('assets/logo.png', height: 72, fit: BoxFit.contain),
            const SizedBox(height: 14),
            Text(
              '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  •  '
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 13,
                color: t.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painters / Clippers ─────────────────────────────────────────────────────
class _DiagonalDividerPainter extends CustomPainter {
  final Color color;
  _DiagonalDividerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _UpperLeftClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) =>
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> _) => false;
}

class _LowerRightClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) =>
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> _) => false;
}
