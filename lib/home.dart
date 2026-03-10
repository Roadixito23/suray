import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_page.dart';
import 'schedules_page.dart';
import 'paraderos_page.dart';
import 'main.dart';
import 'dual_weather_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FirebaseFirestore _firestore;
  final List<StreamSubscription> _streamSubscriptions = [];
  List<String> _aysenTodayTimes = [];
  List<String> _aysenTomorrowTimes = [];
  List<String> _coyhaiqueTodayTimes = [];
  List<String> _coyhaiqueTomorrowTimes = [];
  String? _nextAysenDeparture;
  String? _nextCoyhaiqueDeparture;
  Timer? _timeContextTimer;
  Map<String, Map<String, dynamic>> _holidays = {};
  bool _isTodayHoliday = false;
  String? _todayHolidayName;
  String? _currentDayCollection;

  late final DualWeatherService _weatherService;
  Timer? _weatherUpdateTimer;
  CompactWeatherData? _coyhaqueWeather;
  CompactWeatherData? _puertoAysenWeather;
  bool _isWeatherLoading = true;

  final List<String> _panelImages = [
    'assets/home_panels/puente_aysen.png',
    'assets/home_panels/tunel.png',
  ];
  late final PageController _pageController;
  Timer? _imageRotationTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _weatherService = DualWeatherService();

    _initializeScheduleListeners();
    _timeContextTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _recalculateAndSetDepartures();
    });

    _initializeWeather();
    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _updateWeatherData();
    });

    // Inicializar lógica del carrusel (existente)
    _pageController = PageController(initialPage: 0);
    _startImageRotation();

    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _timeContextTimer?.cancel();
    _imageRotationTimer?.cancel();
    _weatherUpdateTimer?.cancel();
    _pageController.dispose();
    for (var sub in _streamSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  // --- NUEVO: Métodos para el clima ---
  Future<void> _initializeWeather() async {
    await _updateWeatherData();
  }

  Future<void> _updateWeatherData() async {
    try {
      final weatherData = await _weatherService.getBothCurrentWeather();

      if (mounted) {
        setState(() {
          _coyhaqueWeather = CompactWeatherData.fromJson(
            weatherData['coyhaique'],
          );
          _puertoAysenWeather = CompactWeatherData.fromJson(
            weatherData['puertoAysen'],
          );
          _isWeatherLoading = false;
        });
      }
    } catch (e) {
      print('Error actualizando datos del clima: $e');
      if (mounted) {
        setState(() {
          _isWeatherLoading = false;
        });
      }
    }
  }

  void _startImageRotation() {
    _imageRotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      int nextPage = (_currentPage + 1) % _panelImages.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // --- LÓGICA DE DATOS DE HORARIOS (sin cambios) ---
  Future<void> _initializeScheduleListeners() async {
    await _loadHolidays();
    _setupScheduleListeners();
  }

  Future<void> _loadHolidays() async {
    try {
      final currentYear = DateTime.now().year;
      print('📥 Cargando feriados del año $currentYear...');

      final snapshot =
          await _firestore
              .collection('feriados')
              .doc(currentYear.toString())
              .get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        _holidays = Map<String, Map<String, dynamic>>.from(
          data.map(
            (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
          ),
        );

        // Asegurar que todos los feriados tengan tipoHorario
        _holidays.forEach((key, value) {
          if (!value.containsKey('tipoHorario')) {
            value['tipoHorario'] = 'domingo'; // Valor por defecto
          }
        });

        print('✅ Feriados cargados: ${_holidays.length}');
        _holidays.forEach((key, value) {
          print(
            '   - $key: ${value['nombre']} (tipo: ${value['tipoHorario']}, activo: ${value['activo']})',
          );
        });
      } else {
        print('⚠️ No se encontraron feriados para el año $currentYear');
      }
      _checkIfTodayIsHoliday();
    } catch (e) {
      print("❌ Error cargando feriados: $e");
    }
  }

  void _setupScheduleListeners() {
    for (var sub in _streamSubscriptions) {
      sub.cancel();
    }
    _streamSubscriptions.clear();

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    String todayCollection = _getDayCollection(now);
    String tomorrowCollection = _getDayCollection(tomorrow);
    _currentDayCollection = todayCollection;

    print('═══════════════════════════════════════════════');
    print('🔄 Configurando listeners de horarios');
    print('   HOY: $todayCollection');
    print('   MAÑANA: $tomorrowCollection');
    print('═══════════════════════════════════════════════');

    _listenToSchedule(
      'aysen',
      todayCollection,
      (times) => _aysenTodayTimes = times,
    );
    _listenToSchedule(
      'aysen',
      tomorrowCollection,
      (times) => _aysenTomorrowTimes = times,
    );
    _listenToSchedule(
      'coyhaique',
      todayCollection,
      (times) => _coyhaiqueTodayTimes = times,
    );
    _listenToSchedule(
      'coyhaique',
      tomorrowCollection,
      (times) => _coyhaiqueTomorrowTimes = times,
    );
  }

  void _listenToSchedule(
    String region,
    String dayCollection,
    void Function(List<String>) onData,
  ) {
    print('🔍 _listenToSchedule: region=$region, dayCollection=$dayCollection');

    // Caso especial: Sin servicio
    if (dayCollection == 'sinServicio') {
      print('⚠️ Día sin servicio detectado para $region');
      onData([]);
      return;
    }

    // Caso especial: Horarios especiales de feriado
    if (dayCollection.startsWith('feriadoEspecial_')) {
      final parts = dayCollection.split('_');
      final year = parts[1];
      final feriadoKey = parts[2]; // Formato: MM-DD

      print('⭐ HORARIO ESPECIAL detectado:');
      print('   - Región: $region');
      print('   - Año: $year');
      print('   - Feriado: $feriadoKey');
      print('   - Ruta: horarios_especiales_feriados/$year/$region');

      var subscription = _firestore
          .collection('horarios_especiales_feriados')
          .doc(year)
          .collection(region)
          .where('feriado', isEqualTo: feriadoKey)
          .orderBy('time')
          .snapshots()
          .listen(
            (snapshot) {
              print(
                '📦 Snapshot recibido para $region: ${snapshot.docs.length} documentos',
              );
              final times =
                  snapshot.docs.map((doc) {
                    print(
                      '   - Doc ID: ${doc.id}, time: ${doc.data()['time']}',
                    );
                    return doc.data()['time'] as String;
                  }).toList();
              print('✅ Horarios especiales para $region: $times');
              onData(times);
              _recalculateAndSetDepartures();
            },
            onError: (error) {
              print(
                '❌ Error al obtener horarios especiales para $region: $error',
              );
            },
          );
      _streamSubscriptions.add(subscription);
      return;
    }

    // Caso normal: Horarios regulares
    print('📅 Usando horarios regulares para $region: $dayCollection');
    var subscription = _firestore
        .collection('horarios')
        .doc(region)
        .collection(dayCollection)
        .orderBy('time')
        .snapshots()
        .listen((snapshot) {
          final times =
              snapshot.docs.map((doc) => doc.data()['time'] as String).toList();
          onData(times);
          _recalculateAndSetDepartures();
        });
    _streamSubscriptions.add(subscription);
  }

  void _recalculateAndSetDepartures() {
    final nextAysen = _findNextDepartureFromLists(
      _aysenTodayTimes,
      _aysenTomorrowTimes,
    );
    final nextCoyhaique = _findNextDepartureFromLists(
      _coyhaiqueTodayTimes,
      _coyhaiqueTomorrowTimes,
    );
    if (mounted) {
      setState(() {
        _nextAysenDeparture = nextAysen;
        _nextCoyhaiqueDeparture = nextCoyhaique;
      });
    }
  }

  String _formatTimeWithSuffix(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);

      // 00:00 a 11:59 -> a.m.
      // 12:00 a 23:59 -> hrs.
      if (hour >= 0 && hour < 12) {
        return "$time a.m.";
      } else {
        return "$time hrs.";
      }
    } catch (e) {
      return time; // Si hay error, devolver sin sufijo
    }
  }

  String? _findNextDepartureFromLists(
    List<String> todayTimes,
    List<String> tomorrowTimes,
  ) {
    final referenceTime = DateTime.now();

    // Verificar si hoy es día sin servicio
    if (todayTimes.isEmpty) {
      final now = DateTime.now();
      final todayKey =
          "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      if (_holidays.containsKey(todayKey) &&
          _holidays[todayKey]!['tipoHorario'] == 'sinServicio') {
        return "Sin recorrido";
      }
    }

    DateTime? parseTime(String time, DateTime ref) {
      try {
        final p = time.split(':');
        return DateTime(
          ref.year,
          ref.month,
          ref.day,
          int.parse(p[0]),
          int.parse(p[1]),
        );
      } catch (e) {
        return null;
      }
    }

    // Verificar si hay salidas hoy después de la hora actual
    bool hasTodayDepartures = false;
    for (final time in todayTimes) {
      final departureTime = parseTime(time, referenceTime);
      if (departureTime != null && departureTime.isAfter(referenceTime)) {
        hasTodayDepartures = true;
        return "Hoy a las ${_formatTimeWithSuffix(time)}";
      }
    }

    // Si no hay más salidas hoy, verificar mañana
    if (tomorrowTimes.isNotEmpty) {
      return "Mañana a las ${_formatTimeWithSuffix(tomorrowTimes.first)}";
    }

    // Si no hay salidas ni hoy ni mañana
    if (!hasTodayDepartures && tomorrowTimes.isEmpty) {
      return "Sin salidas próximas";
    }

    return null;
  }

  void _checkIfTodayIsHoliday() {
    final now = DateTime.now();
    final todayKey =
        "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (_holidays.containsKey(todayKey) &&
        _holidays[todayKey]!['activo'] == true) {
      _isTodayHoliday = true;
      _todayHolidayName = _holidays[todayKey]!['nombre'];
    } else {
      _isTodayHoliday = false;
      _todayHolidayName = null;
    }
  }

  String _getDayCollection(DateTime date) {
    final dateKey =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    print(
      '📅 _getDayCollection para ${date.day}/${date.month}/${date.year} (key: $dateKey)',
    );

    // Verificar si es feriado y obtener su tipo
    if (_holidays.containsKey(dateKey) &&
        _holidays[dateKey]!['activo'] == true) {
      final tipoHorario = _holidays[dateKey]!['tipoHorario'] ?? 'domingo';
      final nombre = _holidays[dateKey]!['nombre'];

      print('🎉 Feriado detectado: $nombre');
      print('   - Tipo: $tipoHorario');

      switch (tipoHorario) {
        case 'especial':
          // Retornar identificador especial para consultar horarios personalizados
          final resultado = 'feriadoEspecial_${date.year}_$dateKey';
          print('   ⭐ Retornando: $resultado');
          return resultado;
        case 'sinServicio':
          // Retornar identificador para día sin servicio
          print('   ⚠️ Retornando: sinServicio');
          return 'sinServicio';
        case 'domingo':
        default:
          // Usar horarios normales de domingo
          print('   📆 Retornando: domingosFeriados');
          return 'domingosFeriados';
      }
    }

    // Lógica normal para días no feriados
    print('   📆 No es feriado, día normal de la semana');
    if (date.weekday >= 1 && date.weekday <= 5) return 'lunesViernes';
    if (date.weekday == 6) return 'sabados';
    return 'domingosFeriados';
  }

  String _getDayName(int weekday) =>
      {
        1: 'Lunes',
        2: 'Martes',
        3: 'Miércoles',
        4: 'Jueves',
        5: 'Viernes',
        6: 'Sábado',
        7: 'Domingo',
      }[weekday] ??
      'Desconocido';

  String _getMonthAbbreviation(int month) =>
      {
        1: 'ENE',
        2: 'FEB',
        3: 'MAR',
        4: 'ABR',
        5: 'MAY',
        6: 'JUN',
        7: 'JUL',
        8: 'AGO',
        9: 'SEP',
        10: 'OCT',
        11: 'NOV',
        12: 'DIC',
      }[month] ??
      '';

  // --- WIDGETS DE LA PÁGINA DE INICIO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sin AppBar
      body: SelectionArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fondo Dinámico de Pantalla Completa
            PageView.builder(
              controller: _pageController,
              itemCount: _panelImages.length,
              itemBuilder: (context, index) {
                return Image.asset(_panelImages[index], fit: BoxFit.cover);
              },
            ),

            // 2. Gradiente para legibilidad del texto
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MyApp.primaryNavy.withOpacity(0.8),
                    Colors.transparent,
                    MyApp.primaryNavy.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // 3. Contenido de la UI - Footer siempre pegado al fondo
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: OrientationBuilder(
                            builder: (context, orientation) {
                              return Column(
                                children: [
                                  // Header adaptable según orientación
                                  _buildHeader(orientation),

                                  // Contenido principal
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                    ),
                                    child: Column(
                                      children: [
                                        // Tarjeta de Información del Día
                                        _buildCurrentDayInfo(),

                                        const SizedBox(height: 5),

                                        // Botón de Horarios con texto responsive
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => SchedulesPage(
                                                      firestore: _firestore,
                                                      holidays: _holidays,
                                                      nextAysenDeparture:
                                                          _nextAysenDeparture,
                                                      nextCoyhaiqueDeparture:
                                                          _nextCoyhaiqueDeparture,
                                                      currentDayCollection:
                                                          _currentDayCollection,
                                                    ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: MyApp.primaryOrange,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 20,
                                            ),
                                            minimumSize: const Size(
                                              double.infinity,
                                              60,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 3,
                                            shadowColor: MyApp.primaryOrange
                                                .withOpacity(0.4),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Image.asset(
                                                  'assets/icons/bus_reloj.png',
                                                  width: 28,
                                                  height: 28,
                                                  fit: BoxFit.contain,
                                                ),
                                                const SizedBox(width: 14),
                                                const Text(
                                                  'TODOS LOS HORARIOS',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Icon(
                                                  Icons.touch_app_rounded,
                                                  size: 28,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              );
                            },
                          ),
                        ),
                        // Footer siempre pegado al fondo de la pantalla
                        _buildFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Orientation orientation) {
    if (orientation == Orientation.portrait) {
      // Layout vertical: Logo centrado arriba, botones abajo centrados
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            // Logo centrado
            Center(
              child: Image.asset(
                'assets/logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            // Botones centrados debajo del logo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeroNavButton(
                  'Ubícanos',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactPage()),
                  ),
                ),
                const SizedBox(width: 10),
                _buildHeroNavButton(
                  'Ruta',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParaderosPage()),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Layout horizontal: Logo a la izquierda, botones a la derecha
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/logo.png', height: 80, fit: BoxFit.contain),
            Row(
              children: [
                _buildHeroNavButton(
                  'Ubícanos',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactPage()),
                  ),
                ),
                const SizedBox(width: 10),
                _buildHeroNavButton(
                  'Ruta',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParaderosPage()),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHeroNavButton(String text, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        color: Colors.white.withOpacity(0.1),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildCurrentDayInfo() {
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    final dayNumber = now.day;
    final monthAbbr = _getMonthAbbreviation(now.month);
    Color cardColor =
        _isTodayHoliday
            ? MyApp.errorColor.withOpacity(0.9)
            : MyApp.primaryNavy.withOpacity(0.9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: MyApp.primaryNavy.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child:
                      _isTodayHoliday
                          ? Icon(
                            Icons.celebration,
                            color: Colors.white,
                            size: 48,
                          )
                          : Image.asset(
                            'assets/icons/calendario_reloj.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isTodayHoliday
                    ? 'Hoy es Feriado: $_todayHolidayName'
                    : 'Hoy es $dayName $dayNumber de $monthAbbr',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MyApp.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Próximas Salidas:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Hemiheads',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_nextAysenDeparture == null && _nextCoyhaiqueDeparture == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_nextAysenDeparture != null)
                    Expanded(
                      child: _buildDepartureInfoColumn(
                        'Desde Aysén',
                        _nextAysenDeparture!,
                        _puertoAysenWeather,
                      ),
                    ),
                  if (_nextAysenDeparture != null &&
                      _nextCoyhaiqueDeparture != null)
                    const SizedBox(width: 12),
                  if (_nextCoyhaiqueDeparture != null)
                    Expanded(
                      child: _buildDepartureInfoColumn(
                        'Desde Coyhaique',
                        _nextCoyhaiqueDeparture!,
                        _coyhaqueWeather,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartureInfoColumn(
    String city,
    String time,
    CompactWeatherData? weather,
  ) {
    // Caso especial: Sin salidas próximas
    if (time == "Sin salidas próximas") {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              city,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    color: Colors.white70,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Sin salidas\npróximas",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Extraer componentes: día (Hoy/Mañana), hora y sufijo
    String dayPart = '';
    String hourPart = '';
    String suffixPart = '';

    if (time.contains(' a las ')) {
      final parts = time.split(' a las ');
      dayPart = parts[0]; // "Hoy" o "Mañana"
      final timePart = parts[1]; // "16:30 hrs." o "8:00 am"

      // Separar hora del sufijo
      final timeMatch = RegExp(
        r'^(\d{1,2}:\d{2})\s*(.*)$',
      ).firstMatch(timePart);
      if (timeMatch != null) {
        hourPart = timeMatch.group(1) ?? timePart;
        suffixPart = timeMatch.group(2) ?? '';
      } else {
        hourPart = timePart;
      }
    } else {
      hourPart = time;
    }

    // Usar MediaQuery para determinar orientación
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height:
                36, // Altura fija para mantener simetría entre ambos títulos
            child: Center(
              child: Text(
                city,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MyApp.primaryOrange,
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  isLandscape
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (dayPart.isNotEmpty) ...[
                            Flexible(
                              child: Text(
                                dayPart,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Flexible(
                              child: Text(
                                " a las ",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              hourPart,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (suffixPart.isNotEmpty)
                            Flexible(
                              child: Text(
                                " $suffixPart",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (dayPart.isNotEmpty) ...[
                            Text(
                              dayPart,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Text(
                              "a las",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          Text(
                            hourPart,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (suffixPart.isNotEmpty)
                            Text(
                              suffixPart,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 12),
          // Widget del clima
          if (weather != null && weather.hasData)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Ahora:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getCupertinoWeatherIcon(weather.weatherText),
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        weather.temperature,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weather.weatherText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_isWeatherLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  // Función para abrir Instagram
  Future<void> _openInstagram() async {
    final Uri url = Uri.parse(
      'https://www.instagram.com/buses.suray.cargo?igsh=azU1Z2MxbGZiMTZr',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir la URL: $url');
    }
  }

  // Función para abrir Facebook
  Future<void> _openFacebook() async {
    final Uri url = Uri.parse(
      'https://www.facebook.com/buses.suray.cargo',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir la URL: $url');
    }
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD4CFC4), // Color beige/gris del diseño
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sección de Redes Sociales - píldoras centradas arriba
          Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 12.0,
              bottom: 8.0,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0,
              runSpacing: 8.0,
              children: [
                // Botón de Instagram
                InkWell(
                  onTap: _openInstagram,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/insta_icon.png',
                              width: 22,
                              height: 22,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '@buses.suray.cargo',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Botón de Facebook
                InkWell(
                  onTap: _openFacebook,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.facebook,
                          color: Color(0xFF1877F2),
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'buses.suray.cargo',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sección de copyright - al final
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 8.0,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Copyright © 2026 - MMKT GRUPO SURAY - CMO dante@suray.cl',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Función para obtener el ícono del clima de Cupertino
  IconData _getCupertinoWeatherIcon(String? weatherText) {
    if (weatherText == null) return CupertinoIcons.question_circle;
    final lowerCaseText = weatherText.toLowerCase();

    if (lowerCaseText.contains('tormenta') ||
        lowerCaseText.contains('truenos')) {
      return CupertinoIcons.bolt_fill;
    } else if (lowerCaseText.contains('lluvia fuerte') ||
        lowerCaseText.contains('aguacero')) {
      return CupertinoIcons.cloud_heavyrain_fill;
    } else if (lowerCaseText.contains('aguanieve') ||
        (lowerCaseText.contains('lluvia') && lowerCaseText.contains('nieve'))) {
      return CupertinoIcons.cloud_sleet_fill;
    } else if (lowerCaseText.contains('nieve')) {
      return CupertinoIcons.snow;
    } else if (lowerCaseText.contains('lluvia') ||
        lowerCaseText.contains('chubasco')) {
      return CupertinoIcons.cloud_rain_fill;
    } else if (lowerCaseText.contains('llovizna') ||
        lowerCaseText.contains('garúa')) {
      return CupertinoIcons.cloud_drizzle_fill;
    } else if (lowerCaseText.contains('niebla') ||
        lowerCaseText.contains('bruma')) {
      return CupertinoIcons.cloud_fog_fill;
    } else if (lowerCaseText.contains('granizo')) {
      return CupertinoIcons.cloud_hail_fill;
    } else if (lowerCaseText.contains('viento')) {
      return CupertinoIcons.wind;
    } else if (lowerCaseText.contains('algo nublado') ||
        lowerCaseText.contains('parcialmente nublado')) {
      return CupertinoIcons.cloud_sun_fill;
    } else if (lowerCaseText.contains('nublado') ||
        lowerCaseText.contains('nubes')) {
      return CupertinoIcons.cloud_fill;
    } else if (lowerCaseText.contains('despejado') ||
        lowerCaseText.contains('claro')) {
      return CupertinoIcons.sun_max_fill;
    }
    return CupertinoIcons.cloud;
  }
}
