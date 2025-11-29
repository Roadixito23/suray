import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main.dart'; // Para acceder a los colores de la app

// --- Clase principal para generar la imagen del horario ---
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
          Image.asset('assets/logo.png', height: 80),
          const SizedBox(height: 12),
          Text(
            'Horarios Buses Suray - Ruta 240',
            style: const TextStyle(
              fontFamily: 'Hemiheads',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: MyApp.primaryNavy,
            ),
          ),
          const SizedBox(height: 20),

          // --- Tablas de Horarios ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Salidas desde Aysén
              Expanded(
                child: _buildScheduleTable(
                  'Salidas desde Puerto Aysén',
                  aysenSchedules,
                  MyApp.primaryNavy,
                  Icons.location_on_rounded,
                ),
              ),
              const SizedBox(width: 16),
              // Salidas desde Coyhaique
              Expanded(
                child: _buildScheduleTable(
                  'Salidas desde Coyhaique',
                  coyhaiqueSchedules,
                  MyApp.accentBlue,
                  Icons.location_city_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Pie de imagen ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, color: MyApp.lightTextColor, size: 14),
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
        ],
      ),
    );
  }

  /// Widget helper para construir una tabla de horarios individual.
  Widget _buildScheduleTable(String title, Map<String, List<String>> schedules, Color headerColor, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MyApp.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Contenido de la tabla
          _buildScheduleCategory('Lunes a Viernes', schedules['lunesViernes'] ?? []),
          _buildScheduleCategory('Sábados', schedules['sabados'] ?? []),
          _buildScheduleCategory('Domingos y Feriados', schedules['domingosFeriados'] ?? []),
        ],
      ),
    );
  }

  /// Widget helper para una categoría de día (ej. Lunes a Viernes).
  Widget _buildScheduleCategory(String title, List<String> times) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: MyApp.borderColor)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: MyApp.darkTextColor,
            ),
          ),
          const SizedBox(height: 8),
          if (times.isEmpty)
            const Text('No hay horarios', style: TextStyle(fontSize: 11, color: MyApp.lightTextColor))
          else
            // Usamos Wrap para que los horarios fluyan si no caben en una línea
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: times.map((time) => Text(time, style: const TextStyle(fontSize: 11, color: MyApp.darkTextColor))).toList(),
            ),
        ],
      ),
    );
  }
}