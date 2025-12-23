import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
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
        title: const Text('Horarios'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MyApp.primaryOrange,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: MyApp.primaryOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón zoom out
                  IconButton(
                    icon: const Icon(Icons.zoom_out, color: Colors.white),
                    onPressed: _zoomLevel > 0.6 ? () {
                      setState(() {
                        _zoomLevel = (_zoomLevel - 0.1).clamp(0.6, 1.1);
                      });
                    } : null,
                    tooltip: 'Alejar',
                  ),
                  const SizedBox(width: 8),
                  // Indicador de zoom
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_zoomLevel * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón zoom in
                  IconButton(
                    icon: const Icon(Icons.zoom_in, color: Colors.white),
                    onPressed: _zoomLevel < 1.1 ? () {
                      setState(() {
                        _zoomLevel = (_zoomLevel + 0.1).clamp(0.6, 1.1);
                      });
                    } : null,
                    tooltip: 'Acercar',
                  ),
                ],
              ),
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
                  _buildDaySection(
                    'Sábados',
                    'sabados',
                    'saturday',
                    Icons.weekend_rounded,
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
                    Icons.celebration_rounded,
                    primaryColor: MyApp.sundayRed,
                    darkColor: MyApp.sundayRedDark,
                    fontSize: baseFontSize,
                    chipPadding: chipPadding,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Nuevo método para construir sección por día con dos ciudades lado a lado
  Widget _buildDaySection(String dayTitle, String dayCollection, String tableType, IconData icon, {required Color primaryColor, required Color darkColor, double fontSize = 14.0, double chipPadding = 16.0}) {
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
        border: Border.all(
          color: MyApp.borderColor.withOpacity(0.5),
          width: 1,
        ),
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
                Container(
                  width: 2,
                  color: MyApp.borderColor,
                ),
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
  Widget _buildCityScheduleColumn(String cityName, String region, String dayCollection, String tableType, Color accentColor, IconData icon, {double fontSize = 14.0, double chipPadding = 16.0}) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nombre de la ciudad con ícono
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                cityName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize + 4,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                    border: Border.all(color: MyApp.errorColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: MyApp.errorColor, fontSize: fontSize),
                    textAlign: TextAlign.center,
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
                children: times.map((time) => _buildTimeChip(time, region, tableType, times, fontSize: fontSize, chipPadding: chipPadding)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildTimeChip(String time, String region, String tableType, List<String> allTimes, {double fontSize = 14.0, double chipPadding = 16.0}) {
    String? nextDeparture = region == 'aysen' ? widget.nextAysenDeparture : widget.nextCoyhaiqueDeparture;
    final isNext = nextDeparture != null && nextDeparture.contains(time) && _shouldHighlightInThisTable(tableType, nextDeparture);

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
        padding: EdgeInsets.symmetric(horizontal: chipPadding, vertical: chipPadding * 0.75),
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
              child: Icon(
                icon,
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