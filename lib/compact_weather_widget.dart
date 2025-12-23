import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dual_weather_service.dart';

// --- FUNCIÓN HELPER PARA OBTENER EL ÍCONO (AHORA INDEPENDIENTE) ---
IconData _getCupertinoIcon(String? weatherText) {
  if (weatherText == null) {
    return CupertinoIcons.question_circle;
  }

  final lowerCaseText = weatherText.toLowerCase();

  // Mapeo extendido de descripciones de clima a íconos de Cupertino

  // Tormentas eléctricas (prioridad alta)
  if (lowerCaseText.contains('tormenta') ||
      lowerCaseText.contains('rayos') ||
      lowerCaseText.contains('truenos') ||
      lowerCaseText.contains('eléctrica') ||
      lowerCaseText.contains('electrica')) {
    return CupertinoIcons.bolt_fill;
  }

  // Lluvia intensa
  else if (lowerCaseText.contains('lluvia fuerte') ||
           lowerCaseText.contains('lluvia intensa') ||
           lowerCaseText.contains('aguacero') ||
           lowerCaseText.contains('diluvio') ||
           lowerCaseText.contains('torrencial')) {
    return CupertinoIcons.cloud_heavyrain_fill;
  }

  // Lluvia con nieve
  else if (lowerCaseText.contains('aguanieve') ||
           (lowerCaseText.contains('lluvia') && lowerCaseText.contains('nieve')) ||
           lowerCaseText.contains('cellisca')) {
    return CupertinoIcons.cloud_sleet_fill;
  }

  // Nieve
  else if (lowerCaseText.contains('nieve') ||
           lowerCaseText.contains('nevada') ||
           lowerCaseText.contains('nevando') ||
           lowerCaseText.contains('nevada ligera') ||
           lowerCaseText.contains('nevada moderada') ||
           lowerCaseText.contains('nevada fuerte')) {
    return CupertinoIcons.snow;
  }

  // Lluvia (general)
  else if (lowerCaseText.contains('lluvia') ||
           lowerCaseText.contains('lluvioso') ||
           lowerCaseText.contains('lloviendo') ||
           lowerCaseText.contains('chubascos') ||
           lowerCaseText.contains('chubasco') ||
           lowerCaseText.contains('precipitación') ||
           lowerCaseText.contains('precipitacion')) {
    return CupertinoIcons.cloud_rain_fill;
  }

  // Llovizna
  else if (lowerCaseText.contains('llovizna') ||
           lowerCaseText.contains('garúa') ||
           lowerCaseText.contains('garua') ||
           lowerCaseText.contains('calabobos')) {
    return CupertinoIcons.cloud_drizzle_fill;
  }

  // Niebla, bruma, neblina
  else if (lowerCaseText.contains('niebla') ||
           lowerCaseText.contains('bruma') ||
           lowerCaseText.contains('neblina') ||
           lowerCaseText.contains('calima') ||
           lowerCaseText.contains('neblinoso') ||
           lowerCaseText.contains('brumoso')) {
    return CupertinoIcons.cloud_fog_fill;
  }

  // Granizo
  else if (lowerCaseText.contains('granizo') ||
           lowerCaseText.contains('granizada') ||
           lowerCaseText.contains('pedrisco')) {
    return CupertinoIcons.cloud_hail_fill;
  }

  // Viento fuerte
  else if (lowerCaseText.contains('ventoso') ||
           lowerCaseText.contains('viento fuerte') ||
           lowerCaseText.contains('ráfagas') ||
           lowerCaseText.contains('rafagas') ||
           lowerCaseText.contains('vendaval')) {
    return CupertinoIcons.wind;
  }

  // Parcialmente nublado / algo de nubes
  else if (lowerCaseText.contains('algo nublado') ||
           lowerCaseText.contains('parcialmente nublado') ||
           lowerCaseText.contains('poco nublado') ||
           lowerCaseText.contains('nubes dispersas') ||
           lowerCaseText.contains('intervalos nubosos')) {
    return CupertinoIcons.cloud_sun_fill;
  }

  // Muy nublado / cubierto
  else if (lowerCaseText.contains('muy nublado') ||
           lowerCaseText.contains('cubierto') ||
           lowerCaseText.contains('nublado') ||
           lowerCaseText.contains('nubes') ||
           lowerCaseText.contains('nuboso') ||
           lowerCaseText.contains('nubosidad')) {
    return CupertinoIcons.cloud_fill;
  }

  // Despejado / soleado
  else if (lowerCaseText.contains('despejado') ||
           lowerCaseText.contains('soleado') ||
           lowerCaseText.contains('sol') ||
           lowerCaseText.contains('cielo claro') ||
           lowerCaseText.contains('cielo limpio') ||
           lowerCaseText.contains('claro')) {
    return CupertinoIcons.sun_max_fill;
  }

  // Tornado / fenómenos extremos
  else if (lowerCaseText.contains('tornado') ||
           lowerCaseText.contains('huracán') ||
           lowerCaseText.contains('huracan') ||
           lowerCaseText.contains('ciclón') ||
           lowerCaseText.contains('ciclon')) {
    return CupertinoIcons.tornado;
  }

  // Arena / polvo
  else if (lowerCaseText.contains('arena') ||
           lowerCaseText.contains('polvo') ||
           lowerCaseText.contains('arenoso') ||
           lowerCaseText.contains('polvareda')) {
    return CupertinoIcons.wind_snow;
  }

  // Ceniza volcánica
  else if (lowerCaseText.contains('ceniza') ||
           lowerCaseText.contains('volcánica') ||
           lowerCaseText.contains('volcanica')) {
    return CupertinoIcons.smoke_fill;
  }

  // Humo
  else if (lowerCaseText.contains('humo') ||
           lowerCaseText.contains('ahumado')) {
    return CupertinoIcons.smoke_fill;
  }

  // Luna (noche despejada)
  else if (lowerCaseText.contains('noche') &&
          (lowerCaseText.contains('despejado') || lowerCaseText.contains('claro'))) {
    return CupertinoIcons.moon_stars_fill;
  }

  // Por defecto
  else {
    return CupertinoIcons.cloud; // Ícono de nube genérico en lugar de interrogación
  }
}

class CompactWeatherWidget extends StatelessWidget {
  final CompactWeatherData? coyhaique;
  final CompactWeatherData? puertoAysen;
  final bool isLoading;

  const CompactWeatherWidget({
    super.key,
    this.coyhaique,
    this.puertoAysen,
    required this.isLoading,
  });

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
    super.key,
    this.coyhaique,
    this.puertoAysen,
    required this.isLoading,
  });

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