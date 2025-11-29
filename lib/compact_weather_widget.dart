import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dual_weather_service.dart';

// --- FUNCIÓN HELPER PARA OBTENER EL ÍCONO (AHORA INDEPENDIENTE) ---
IconData _getCupertinoIcon(String? weatherText) {
  if (weatherText == null) {
    return CupertinoIcons.question_circle;
  }

  final lowerCaseText = weatherText.toLowerCase();

  // Mapeo de descripciones de clima a íconos de Cupertino
  if (lowerCaseText.contains('soleado') || lowerCaseText.contains('despejado')) {
    return CupertinoIcons.sun_max_fill;
  } else if (lowerCaseText.contains('nubes') || lowerCaseText.contains('nublado') || lowerCaseText.contains('cubierto')) {
    return CupertinoIcons.cloud_fill;
  } else if (lowerCaseText.contains('lluvia') || lowerCaseText.contains('llovizna') || lowerCaseText.contains('aguacero') || lowerCaseText.contains('chubascos')) {
    return CupertinoIcons.cloud_rain_fill;
  } else if (lowerCaseText.contains('nieve') || lowerCaseText.contains('aguanieve') || lowerCaseText.contains('hielo') || lowerCaseText.contains('nevada')) {
    return CupertinoIcons.snow;
  } else if (lowerCaseText.contains('tormenta') || lowerCaseText.contains('rayos') || lowerCaseText.contains('truenos')) {
    return CupertinoIcons.bolt_fill;
  } else if (lowerCaseText.contains('niebla') || lowerCaseText.contains('bruma')) {
    return CupertinoIcons.cloud_fog_fill;
  } else {
    return CupertinoIcons.question_circle; // Ícono por defecto si no coincide
  }
}

class CompactWeatherWidget extends StatelessWidget {
  final CompactWeatherData? coyhaique;
  final CompactWeatherData? puertoAysen;
  final bool isLoading;

  const CompactWeatherWidget({
    Key? key,
    this.coyhaique,
    this.puertoAysen,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CupertinoActivityIndicator(
                radius: 8,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Cargando clima...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clima de Coyhaique
          _buildCityWeather('Coyhaique', coyhaique),

          // Separador
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 20,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),

          // Clima de Puerto Aysén
          _buildCityWeather('P. Aysén', puertoAysen),
        ],
      ),
    );
  }

  Widget _buildCityWeather(String cityName, CompactWeatherData? weatherData) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nombre de la ciudad
        Text(
          cityName,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),

        // Temperatura e ícono
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono del clima
            if (weatherData?.hasData == true)
              Icon(
                _getCupertinoIcon(weatherData!.weatherText),
                size: 20,
                color: Colors.white,
              )
            else
              const Icon(
                CupertinoIcons.question_circle,
                size: 16,
                color: Colors.white,
              ),

            const SizedBox(width: 4),

            // Temperatura
            Text(
              weatherData?.temperature ?? '--°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Widget alternativo más compacto si el espacio es limitado
class SuperCompactWeatherWidget extends StatelessWidget {
  final CompactWeatherData? coyhaique;
  final CompactWeatherData? puertoAysen;
  final bool isLoading;

  // CORREGIDO: Se quitó el 'const' del constructor para evitar errores
  const SuperCompactWeatherWidget({
    Key? key,
    this.coyhaique,
    this.puertoAysen,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CupertinoActivityIndicator(radius: 6),
            ),
            SizedBox(width: 6),
            Text(
              'Clima',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coyhaique
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCupertinoIcon(coyhaique?.weatherText),
                size: 10,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                coyhaique?.temperature ?? '--°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          Text(
            ' | ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
          ),

          // Puerto Aysén
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCupertinoIcon(puertoAysen?.weatherText),
                size: 10,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                puertoAysen?.temperature ?? '--°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}