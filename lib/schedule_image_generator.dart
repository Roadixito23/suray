import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main.dart';

// --- Clase principal para generar la imagen del horario ---
// VERSIÓN SIN FUENTES PERSONALIZADAS PARA MÁXIMA COMPATIBILIDAD
class ScheduleImageGenerator {
  final Map<String, List<String>> aysenSchedules;
  final Map<String, List<String>> coyhaiqueSchedules;

  ScheduleImageGenerator({
    required this.aysenSchedules,
    required this.coyhaiqueSchedules,
  });

  /// Construye el widget que se convertirá en imagen.
  Widget buildScheduleImage() {
    // Formateador para la fecha del pie de página
    final String formattedDate = DateFormat('dd/MM/yyyy \'a las\' HH:mm').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MyApp.surfaceWhite,
            MyApp.lightGreyBackground,
          ],
        ),
        border: Border.all(color: MyApp.primaryNavy, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Encabezado ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MyApp.primaryNavy, MyApp.lightNavy],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'BUSES SURAY',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: MyApp.primaryOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ruta 240',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Horarios de Buses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: MyApp.primaryNavy,
            ),
          ),
          const SizedBox(height: 16),

          // --- Nueva estructura: Encabezados por sección con dos columnas ---

          // Sección Lunes a Viernes
          _buildDaySection(
            'Lunes a Viernes',
            aysenSchedules['lunesViernes'] ?? [],
            coyhaiqueSchedules['lunesViernes'] ?? [],
            Icons.work_rounded,
          ),
          const SizedBox(height: 16),

          // Sección Sábados
          _buildDaySection(
            'Sábados',
            aysenSchedules['sabados'] ?? [],
            coyhaiqueSchedules['sabados'] ?? [],
            Icons.weekend_rounded,
          ),
          const SizedBox(height: 16),

          // Sección Domingo o Feriado
          _buildDaySection(
            'Domingo o Feriado',
            aysenSchedules['domingosFeriados'] ?? [],
            coyhaiqueSchedules['domingosFeriados'] ?? [],
            Icons.celebration_rounded,
          ),
          const SizedBox(height: 20),

          // --- Pie de imagen ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MyApp.primaryNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: MyApp.lightTextColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Imagen descargada el día $formattedDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MyApp.lightTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget helper para construir una sección de día con dos columnas (Aysén y Coyhaique).
  Widget _buildDaySection(String dayTitle, List<String> aysenTimes, List<String> coyhaiqueTimes, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MyApp.primaryNavy, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: MyApp.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: MyApp.primaryNavy.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Encabezado común para el tipo de día
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MyApp.primaryOrange, MyApp.deepOrange],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  dayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
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
                // Columna Aysén
                Expanded(
                  child: _buildCityColumn(
                    'Puerto Aysén',
                    aysenTimes,
                    MyApp.primaryNavy,
                    Icons.location_on_rounded,
                    isLeft: true,
                  ),
                ),
                // Separador vertical
                Container(
                  width: 2,
                  color: MyApp.borderColor,
                ),
                // Columna Coyhaique
                Expanded(
                  child: _buildCityColumn(
                    'Coyhaique',
                    coyhaiqueTimes,
                    MyApp.accentBlue,
                    Icons.location_city_rounded,
                    isLeft: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget helper para construir una columna de ciudad individual.
  Widget _buildCityColumn(String cityName, List<String> times, Color accentColor, IconData icon, {required bool isLeft}) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nombre de la ciudad con ícono
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                cityName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horarios
          if (times.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'No hay horarios',
                style: TextStyle(
                  fontSize: 11,
                  color: MyApp.lightTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Wrap(
              spacing: 5.0,
              runSpacing: 5.0,
              alignment: WrapAlignment.center,
              children: times.map((time) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.1),
                      accentColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: MyApp.darkTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}