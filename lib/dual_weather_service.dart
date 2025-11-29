import 'dart:convert';
import 'package:http/http.dart' as http;

class DualWeatherService {
  static const String baseUrl = 'http://dataservice.accuweather.com';
  static const String coyhaique = '51889';
  static const String puertoAysen = '56887';

  String get apiKey => 'R0oM8CQWLvFeEnGvCwMK2BoAIgLJCpKw';

  // Obtener clima actual para una ciudad específica
  Future<Map<String, dynamic>?> getCurrentWeather(String locationKey) async {
    try {
      final url = Uri.parse(
          '$baseUrl/currentconditions/v1/$locationKey?apikey=$apiKey&language=es&details=false'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty ? data[0] : null;
      } else {
        print('Error al obtener clima para $locationKey: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error al obtener clima actual para $locationKey: $e');
      return null;
    }
  }

  // Obtener clima actual para ambas ciudades
  Future<Map<String, Map<String, dynamic>?>> getBothCurrentWeather() async {
    try {
      final futures = await Future.wait([
        getCurrentWeather(coyhaique),
        getCurrentWeather(puertoAysen),
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

    return CompactWeatherData(
      temperature: '${(json['Temperature']?['Metric']?['Value'] ?? 0.0).round()}°',
      weatherText: json['WeatherText'] ?? 'Sin datos',
      weatherIcon: json['WeatherIcon'] ?? 1,
      hasData: true,
    );
  }
}