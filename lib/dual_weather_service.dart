import 'dart:convert';
import 'package:http/http.dart' as http;

class DualWeatherService {
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // Coordenadas de las ciudades
  static const double coyhaiqueLat = -45.5752;
  static const double coyhaiqueLon = -72.0662;
  static const double puertoAysenLat = -45.40303;
  static const double puertoAysenLon = -72.69184;

  // API Key encriptada (XOR + Base64) - OpenWeatherMap
  static const String _encrypted = 'MWY0ODFmNDg0YTQ0MWYxOTQ1NDU0ZDE4NGM0YTRiNGI0NDE5NGI0NTFiNDgxZjFmMWM0ZTRmNGY0NTE5NDU0Yw==';
  static const int _xorKey = 0x7D;

  String get _apiKey {
    try {
      final decoded = base64.decode(_encrypted);
      final hex = utf8.decode(decoded);
      final bytes = <int>[];

      for (int i = 0; i < hex.length; i += 2) {
        final byte = int.parse(hex.substring(i, i + 2), radix: 16);
        bytes.add(byte ^ _xorKey);
      }

      return utf8.decode(bytes);
    } catch (e) {
      print('Error decodificando API key: $e');
      return '';
    }
  }

  // Obtener clima actual para una ciudad específica por coordenadas
  Future<Map<String, dynamic>?> getCurrentWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
          '$baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=es'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error al obtener clima para lat:$lat, lon:$lon: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error al obtener clima actual para lat:$lat, lon:$lon: $e');
      return null;
    }
  }

  // Obtener clima actual para ambas ciudades
  Future<Map<String, Map<String, dynamic>?>> getBothCurrentWeather() async {
    try {
      final futures = await Future.wait([
        getCurrentWeather(coyhaiqueLat, coyhaiqueLon),
        getCurrentWeather(puertoAysenLat, puertoAysenLon),
      ]);

      return {
        'coyhaique': futures[0],
        'puertoAysen': futures[1],
      };
    } catch (e) {
      print('Error al obtener clima de ambas ciudades: $e');
      return {
        'coyhaique': null,
        'puertoAysen': null,
      };
    }
  }
}

class CompactWeatherData {
  final String temperature;
  final String weatherText;
  final int weatherIcon;
  final bool hasData;

  CompactWeatherData({
    required this.temperature,
    required this.weatherText,
    required this.weatherIcon,
    required this.hasData,
  });

  factory CompactWeatherData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CompactWeatherData(
        temperature: '--',
        weatherText: 'Sin datos',
        weatherIcon: 1,
        hasData: false,
      );
    }

    // Adaptado para OpenWeatherMap API
    final temp = json['main']?['temp'];
    final weatherList = json['weather'] as List?;
    final weatherInfo = weatherList != null && weatherList.isNotEmpty ? weatherList[0] : null;

    return CompactWeatherData(
      temperature: temp != null ? '${temp.round()}°' : '--°',
      weatherText: weatherInfo?['description'] ?? 'Sin datos',
      weatherIcon: _mapWeatherIcon(weatherInfo?['id']),
      hasData: true,
    );
  }

  // Mapea los códigos de OpenWeatherMap a iconos similares de AccuWeather
  static int _mapWeatherIcon(int? code) {
    if (code == null) return 1;

    // Códigos de OpenWeatherMap a iconos aproximados
    if (code >= 200 && code < 300) return 15; // Tormenta
    if (code >= 300 && code < 400) return 12; // Llovizna
    if (code >= 500 && code < 600) return 12; // Lluvia
    if (code >= 600 && code < 700) return 22; // Nieve
    if (code >= 700 && code < 800) return 11; // Neblina
    if (code == 800) return 1; // Despejado
    if (code > 800) return 7; // Nublado

    return 1;
  }
}