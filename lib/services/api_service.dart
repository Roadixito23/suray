import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // URL base de la API - CAMBIAR EN PRODUCCIÓN
  static const String _baseUrl = 'http://localhost:3000/api';

  // Para producción, usar la URL de tu servidor:
  // static const String _baseUrl = 'https://tu-dominio.com/api';

  // Headers comunes
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  // ---------- HORARIOS ----------

  /// Obtener horarios por región y tipo de día
  /// [region]: 'aysen' o 'coyhaique'
  /// [tipoDia]: 'lunesViernes', 'sabados', 'domingosFeriados'
  static Future<List<String>> getHorarios(String region, String tipoDia) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/horarios/$region/$tipoDia'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Convertir a lista de strings (horarios)
        return data.map((item) => item['time'] as String).toList();
      } else {
        throw Exception('Error al obtener horarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getHorarios: $e');
      rethrow;
    }
  }

  /// Obtener todos los horarios de una región agrupados por tipo de día
  static Future<Map<String, List<String>>> getAllHorariosByRegion(
    String region,
  ) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/horarios/$region'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Convertir cada tipo de día a lista de strings
        final result = <String, List<String>>{};
        data.forEach((key, value) {
          if (value is List) {
            result[key] =
                (value).map((item) => item['time'] as String).toList();
          }
        });

        return result;
      } else {
        throw Exception('Error al obtener horarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getAllHorariosByRegion: $e');
      rethrow;
    }
  }

  /// Crear un nuevo horario
  static Future<void> createHorario({
    required String region,
    required String tipoDia,
    required String hora,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/horarios'),
            headers: _headers,
            body: json.encode({
              'region': region,
              'tipo_dia': tipoDia,
              'hora': hora,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 201) {
        throw Exception('Error al crear horario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en createHorario: $e');
      rethrow;
    }
  }

  /// Eliminar un horario
  static Future<void> deleteHorario(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/horarios/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar horario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en deleteHorario: $e');
      rethrow;
    }
  }

  // ---------- FERIADOS ----------

  /// Obtener feriados por año
  static Future<Map<String, Map<String, dynamic>>> getFeriados(int anio) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/feriados/$anio'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Convertir a formato Map<String, Map<String, dynamic>>
        final result = <String, Map<String, dynamic>>{};
        data.forEach((key, value) {
          result[key] = Map<String, dynamic>.from(value as Map);
        });

        return result;
      } else {
        throw Exception('Error al obtener feriados: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getFeriados: $e');
      rethrow;
    }
  }

  /// Crear un nuevo feriado
  static Future<void> createFeriado({
    required int anio,
    required int mes,
    required int dia,
    required String nombre,
    bool activo = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/feriados'),
            headers: _headers,
            body: json.encode({
              'anio': anio,
              'mes': mes,
              'dia': dia,
              'nombre': nombre,
              'activo': activo,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 201) {
        throw Exception('Error al crear feriado: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en createFeriado: $e');
      rethrow;
    }
  }

  /// Actualizar un feriado
  static Future<void> updateFeriado({
    required int id,
    String? nombre,
    bool? activo,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nombre != null) body['nombre'] = nombre;
      if (activo != null) body['activo'] = activo;

      final response = await http
          .put(
            Uri.parse('$_baseUrl/feriados/$id'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar feriado: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en updateFeriado: $e');
      rethrow;
    }
  }

  /// Eliminar un feriado
  static Future<void> deleteFeriado(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/feriados/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar feriado: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en deleteFeriado: $e');
      rethrow;
    }
  }

  // ---------- HEALTH CHECK ----------

  /// Verificar si la API está disponible
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl.replaceAll('/api', '')}/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error en checkHealth: $e');
      return false;
    }
  }
}
