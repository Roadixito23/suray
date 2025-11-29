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
          // --- Encabezado SIN fuentes personalizadas ---
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
                // CAMBIADO: Sin fontFamily personalizada
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
          // CAMBIADO: Sin fontFamily personalizada
          const Text(
            'Horarios de Buses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: MyApp.primaryNavy,
            ),
          ),
          const SizedBox(height: 16),

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

  /// Widget helper para construir una tabla de horarios individual.
  Widget _buildScheduleTable(String title, Map<String, List<String>> schedules, Color headerColor, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MyApp.borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: MyApp.surfaceWhite,
      ),
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: MyApp.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MyApp.primaryOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: MyApp.darkTextColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (times.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
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
          // Usamos Wrap para que los horarios fluyan si no caben en una línea
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              alignment: WrapAlignment.center,
              children: times.map((time) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MyApp.lightGreyBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MyApp.borderColor, width: 1),
                ),
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MyApp.darkTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}