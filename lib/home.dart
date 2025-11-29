import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contact_page.dart';
import 'route_page.dart';
import 'schedules_page.dart';
import 'main.dart';
import 'dual_weather_service.dart';
import 'compact_weather_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- Estado y Lógica de Horarios (existente) ---
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

  // --- NUEVO: Estado y Lógica del Clima ---
  late final DualWeatherService _weatherService;
  Timer? _weatherUpdateTimer;
  CompactWeatherData? _coyhaqueWeather;
  CompactWeatherData? _puertoAysenWeather;
  bool _isWeatherLoading = true;

  // --- Lógica para el carrusel de imágenes (existente) ---
  final List<String> _panelImages = [
    'assets/home_panels/aysen.png',
    'assets/home_panels/tunel.png',
    'assets/home_panels/buses.png',
    'assets/home_panels/terminal_coy.png',
    'assets/home_panels/puente_aysen.png',
  ];
  late final PageController _pageController;
  Timer? _imageRotationTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _weatherService = DualWeatherService(); // Nuevo

    // Inicializar lógica de horarios (existente)
    _initializeScheduleListeners();
    _timeContextTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _recalculateAndSetDepartures();
    });

    // NUEVO: Inicializar lógica del clima
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
    _weatherUpdateTimer?.cancel(); // Nuevo
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
          _coyhaqueWeather = CompactWeatherData.fromJson(weatherData['coyhaique']);
          _puertoAysenWeather = CompactWeatherData.fromJson(weatherData['puertoAysen']);
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
      final snapshot = await _firestore.collection('feriados').doc(currentYear.toString()).get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        _holidays = Map<String, Map<String, dynamic>>.from(
            data.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))));
      }
      _checkIfTodayIsHoliday();
    } catch (e) {
      print("Error cargando feriados: $e");
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

    _listenToSchedule('aysen', todayCollection, (times) => _aysenTodayTimes = times);
    _listenToSchedule('aysen', tomorrowCollection, (times) => _aysenTomorrowTimes = times);
    _listenToSchedule('coyhaique', todayCollection, (times) => _coyhaiqueTodayTimes = times);
    _listenToSchedule('coyhaique', tomorrowCollection, (times) => _coyhaiqueTomorrowTimes = times);
  }

  void _listenToSchedule(String region, String dayCollection, void Function(List<String>) onData) {
    var subscription = _firestore
        .collection('horarios').doc(region).collection(dayCollection).orderBy('time')
        .snapshots()
        .listen((snapshot) {
      final times = snapshot.docs.map((doc) => doc.data()['time'] as String).toList();
      onData(times);
      _recalculateAndSetDepartures();
    });
    _streamSubscriptions.add(subscription);
  }

  void _recalculateAndSetDepartures() {
    final nextAysen = _findNextDepartureFromLists(_aysenTodayTimes, _aysenTomorrowTimes);
    final nextCoyhaique = _findNextDepartureFromLists(_coyhaiqueTodayTimes, _coyhaiqueTomorrowTimes);
    if (mounted) {
      setState(() {
        _nextAysenDeparture = nextAysen;
        _nextCoyhaiqueDeparture = nextCoyhaique;
      });
    }
  }

  String? _findNextDepartureFromLists(List<String> todayTimes, List<String> tomorrowTimes) {
    final referenceTime = DateTime.now();
    DateTime? _parseTime(String time, DateTime ref) {
      try {
        final p = time.split(':');
        return DateTime(ref.year, ref.month, ref.day, int.parse(p[0]), int.parse(p[1]));
      } catch (e) { return null; }
    }
    for (final time in todayTimes) {
      final departureTime = _parseTime(time, referenceTime);
      if (departureTime != null && departureTime.isAfter(referenceTime)) return time;
    }
    if (tomorrowTimes.isNotEmpty) return "${tomorrowTimes.first} (mañana)";
    return null;
  }

  void _checkIfTodayIsHoliday() {
    final now = DateTime.now();
    final todayKey = "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (_holidays.containsKey(todayKey) && _holidays[todayKey]!['activo'] == true) {
      _isTodayHoliday = true;
      _todayHolidayName = _holidays[todayKey]!['nombre'];
    } else {
      _isTodayHoliday = false;
      _todayHolidayName = null;
    }
  }

  bool _isDateHoliday(DateTime date) {
    final dateKey = "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _holidays.containsKey(dateKey) && _holidays[dateKey]!['activo'] == true;
  }

  String _getDayCollection(DateTime date) {
    if (_isDateHoliday(date)) return 'domingosFeriados';
    if (date.weekday >= 1 && date.weekday <= 5) return 'lunesViernes';
    if (date.weekday == 6) return 'sabados';
    return 'domingosFeriados';
  }

  String _getDayName(int weekday) => {1: 'Lunes', 2: 'Martes', 3: 'Miércoles', 4: 'Jueves', 5: 'Viernes', 6: 'Sábado', 7: 'Domingo'}[weekday] ?? 'Desconocido';

  String _getDayTypeDescription(DateTime date) {
    if (_isDateHoliday(date)) return 'Feriado: ${_holidays["${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"]!['nombre']}';
    switch (_getDayCollection(date)) {
      case 'lunesViernes': return 'Horario de Lunes a Viernes';
      case 'sabados': return 'Horario de Sábado';
      case 'domingosFeriados': return 'Horario de Domingo y Feriados';
      default: return 'Horario Desconocido';
    }
  }

  // --- WIDGETS DE LA PÁGINA DE INICIO ---

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      body: SelectionArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fondo Dinámico de Pantalla Completa
            PageView.builder(
              controller: _pageController,
              itemCount: _panelImages.length,
              itemBuilder: (context, index) {
                return Image.asset(
                  _panelImages[index],
                  fit: BoxFit.cover,
                );
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
                    MyApp.primaryNavy.withOpacity(0.9)
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // 3. Contenido de la UI
            SafeArea(
              // INICIO DE LA MODIFICACIÓN: Se añade SingleChildScrollView para scroll vertical
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Column(
                    children: [
                      // --- Fila Superior Adaptativa ---
                      LayoutBuilder(
                          builder: (context, constraints) {
                            if (isSmallScreen) {
                              // VISTA PARA PANTALLAS PEQUEÑAS (VERTICAL)
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Image.asset('assets/logo.png', height: 60, fit: BoxFit.contain),
                                      CompactWeatherWidget(
                                        coyhaique: _coyhaqueWeather,
                                        puertoAysen: _puertoAysenWeather,
                                        isLoading: _isWeatherLoading,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildHeroNavButton('Contacto', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
                                      const SizedBox(width: 10),
                                      _buildHeroNavButton('Nuestra Ruta', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetroMapRoute()))),
                                    ],
                                  ),
                                ],
                              );
                            } else {
                              // VISTA PARA PANTALLAS GRANDES (HORIZONTAL - ORIGINAL)
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Image.asset('assets/logo.png', height: 100, fit: BoxFit.contain),
                                  Expanded(
                                    child: Center(
                                      child: CompactWeatherWidget(
                                        coyhaique: _coyhaqueWeather,
                                        puertoAysen: _puertoAysenWeather,
                                        isLoading: _isWeatherLoading,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildHeroNavButton('Contacto', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
                                      const SizedBox(width: 10),
                                      _buildHeroNavButton('Nuestra Ruta', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetroMapRoute()))),
                                    ],
                                  ),
                                ],
                              );
                            }
                          }
                      ),

                      // INICIO DE LA MODIFICACIÓN: Se reemplaza Spacer por SizedBox
                      const SizedBox(height: 30),

                      // --- Título Adaptativo ---
                      Text(
                        'Horarios de Buses Suray Ruta 240',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Hemiheads',
                          fontSize: isSmallScreen ? 32 : 42,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: const [Shadow(blurRadius: 10.0, color: Colors.black87, offset: Offset(2.0, 2.0))],
                        ),
                      ),

                      // INICIO DE LA MODIFICACIÓN: Se reemplaza Spacer por SizedBox
                      const SizedBox(height: 40),

                      // Tarjeta de Información del Día
                      _buildCurrentDayInfo(),

                      // Indicadores de Página
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_panelImages.length, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              height: 8.0,
                              width: _currentPage == index ? 24.0 : 8.0,
                              decoration: BoxDecoration(
                                color: _currentPage == index ? MyApp.primaryOrange : Colors.white54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Botón de Horarios
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('VER HORARIOS COMPLETOS'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SchedulesPage(
                              firestore: _firestore,
                              holidays: _holidays,
                              nextAysenDeparture: _nextAysenDeparture,
                              nextCoyhaiqueDeparture: _nextCoyhaiqueDeparture,
                              currentDayCollection: _currentDayCollection,
                            )),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyApp.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          shadowColor: MyApp.primaryOrange.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // FIN DE LA MODIFICACIÓN
            ),
          ],
        ),
      ),
    );
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
    final dayTypeDescription = _getDayTypeDescription(now);
    Color cardColor = _isTodayHoliday
        ? MyApp.errorColor.withOpacity(0.9)
        : MyApp.primaryNavy.withOpacity(0.9);
    IconData dayIcon = _isTodayHoliday ? Icons.celebration : Icons.calendar_today;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(dayIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isTodayHoliday ? 'Hoy es Feriado: $_todayHolidayName' : 'Hoy es $dayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dayTypeDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const Divider(color: Colors.white24, height: 24),
          const Text(
            'Próximas Salidas:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (_nextAysenDeparture == null && _nextCoyhaiqueDeparture == null)
            const Center(child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ))
          else ...[
            if (_nextAysenDeparture != null)
              _buildDepartureInfoRow('Desde Aysén:', _nextAysenDeparture!),
            if (_nextCoyhaiqueDeparture != null)
              _buildDepartureInfoRow('Desde Coyhaique:', _nextCoyhaiqueDeparture!),
          ]
        ],
      ),
    );
  }

  Widget _buildDepartureInfoRow(String label, String time) {
    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MyApp.primaryOrange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                  children: [
                    TextSpan(
                      text: '$label ',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    TextSpan(
                      text: time,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ]
              ),
            ),
          )
        ],
      ),
    );
  }
}