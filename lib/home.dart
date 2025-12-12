import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_page.dart';
import 'schedules_page.dart';
import 'main.dart';
import 'dual_weather_service.dart';

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
    'assets/home_panels/tunel.png',
    'assets/home_panels/aysen.png',
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
      if (departureTime != null && departureTime.isAfter(referenceTime)) {
        return "Hoy a las ${_formatTimeWithSuffix(time)}";
      }
    }
    if (tomorrowTimes.isNotEmpty) {
      return "Mañana a las ${_formatTimeWithSuffix(tomorrowTimes.first)}";
    }
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

  String _getMonthAbbreviation(int month) => {1: 'ENE', 2: 'FEB', 3: 'MAR', 4: 'ABR', 5: 'MAY', 6: 'JUN', 7: 'JUL', 8: 'AGO', 9: 'SEP', 10: 'OCT', 11: 'NOV', 12: 'DIC'}[month] ?? '';

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
              bottom: false, // No aplicar padding inferior para que el footer esté pegado al borde
              child: Column(
                children: [
                  // AppBar fija en la parte superior
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: isSmallScreen
                        ? Column(
                            children: [
                              Center(
                                child: Image.asset('assets/logo.png', height: 50, fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildHeroNavButton('Contacto', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
                                  const SizedBox(width: 10),
                                  _buildHeroNavButton('Nuestra Ruta', () {}), // Deshabilitado temporalmente
                                ],
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image.asset('assets/logo.png', height: 80, fit: BoxFit.contain),
                              Row(
                                children: [
                                  _buildHeroNavButton('Contacto', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
                                  const SizedBox(width: 10),
                                  _buildHeroNavButton('Nuestra Ruta', () {}), // Deshabilitado temporalmente
                                ],
                              ),
                            ],
                          ),
                  ),

                  // Contenido principal con scroll si es necesario
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 70.0),
                        child: Column(
                          children: [
                            // Tarjeta de Información del Día
                            _buildCurrentDayInfo(),

                            const SizedBox(height: 20),

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
                                backgroundColor: Colors.black,
                                foregroundColor: MyApp.primaryOrange,
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
                  ),
                ],
              ),
            ),

            // 4. Footer siempre visible en la parte inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFooter(isSmallScreen),
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
    final dayNumber = now.day;
    final monthAbbr = _getMonthAbbreviation(now.month);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
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
          Center(
            child: Text(
              'HORARIOS',
              style: TextStyle(
                fontSize: isSmallScreen ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Hemiheads',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
              Flexible(
                child: Text(
                  _isTodayHoliday
                      ? 'Hoy es Feriado: $_todayHolidayName'
                      : 'Hoy es $dayName $dayNumber de $monthAbbr',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  fontSize: isSmallScreen ? 16 : 20,
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
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_nextAysenDeparture != null)
                    Expanded(
                      child: _buildDepartureInfoColumn('Desde Aysén', _nextAysenDeparture!, _puertoAysenWeather),
                    ),
                  if (_nextAysenDeparture != null && _nextCoyhaiqueDeparture != null)
                    const SizedBox(width: 12),
                  if (_nextCoyhaiqueDeparture != null)
                    Expanded(
                      child: _buildDepartureInfoColumn('Desde Coyhaique', _nextCoyhaiqueDeparture!, _coyhaqueWeather),
                    ),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildDepartureInfoColumn(String city, String time, CompactWeatherData? weather) {
    // Lógica para separar "Hoy/Mañana", "a las" y la hora para mejor control del layout
    List<Widget> timeWidgets = [];
    if (time.contains(' a las ')) {
      final parts = time.split(' a las ');
      timeWidgets = [
        Text(parts[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text("a las", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        Text(parts[1], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ];
    } else {
      timeWidgets = [
        Text(
          time,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        )
      ];
    }

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
          Text(
            city,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MyApp.primaryOrange,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: timeWidgets,
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(),
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
    final Uri url = Uri.parse('https://www.instagram.com/buses.suray.cargo?igsh=azU1Z2MxbGZiMTZr');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir la URL: $url');
    }
  }

  // Widget del Footer
  Widget _buildFooter(bool isSmallScreen) {
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10.0 : 20.0,
            vertical: isSmallScreen ? 8.0 : 12.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Copyright © 2025 - MMKT GRUPO SURAY - CMO dante@suray.cl',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 20),
              // Área clickeable para Instagram
              InkWell(
                onTap: _openInstagram,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/insta_icon.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '@buses.suray.cargo',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función para obtener el ícono del clima de Cupertino
  IconData _getCupertinoWeatherIcon(String? weatherText) {
    if (weatherText == null) return CupertinoIcons.question_circle;
    final lowerCaseText = weatherText.toLowerCase();

    if (lowerCaseText.contains('tormenta') || lowerCaseText.contains('truenos')) {
      return CupertinoIcons.bolt_fill;
    } else if (lowerCaseText.contains('lluvia fuerte') || lowerCaseText.contains('aguacero')) {
      return CupertinoIcons.cloud_heavyrain_fill;
    } else if (lowerCaseText.contains('aguanieve') || (lowerCaseText.contains('lluvia') && lowerCaseText.contains('nieve'))) {
      return CupertinoIcons.cloud_sleet_fill;
    } else if (lowerCaseText.contains('nieve')) {
      return CupertinoIcons.snow;
    } else if (lowerCaseText.contains('lluvia') || lowerCaseText.contains('chubasco')) {
      return CupertinoIcons.cloud_rain_fill;
    } else if (lowerCaseText.contains('llovizna') || lowerCaseText.contains('garúa')) {
      return CupertinoIcons.cloud_drizzle_fill;
    } else if (lowerCaseText.contains('niebla') || lowerCaseText.contains('bruma')) {
      return CupertinoIcons.cloud_fog_fill;
    } else if (lowerCaseText.contains('granizo')) {
      return CupertinoIcons.cloud_hail_fill;
    } else if (lowerCaseText.contains('viento')) {
      return CupertinoIcons.wind;
    } else if (lowerCaseText.contains('algo nublado') || lowerCaseText.contains('parcialmente nublado')) {
      return CupertinoIcons.cloud_sun_fill;
    } else if (lowerCaseText.contains('nublado') || lowerCaseText.contains('nubes')) {
      return CupertinoIcons.cloud_fill;
    } else if (lowerCaseText.contains('despejado') || lowerCaseText.contains('claro')) {
      return CupertinoIcons.sun_max_fill;
    }
    return CupertinoIcons.cloud;
  }
}