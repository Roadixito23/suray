import re

def parse_gpx(filename):
    """Extrae coordenadas lat/lon de un archivo GPX"""
    points = []
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
        # Buscar todos los trkpt con lat y lon
        pattern = r'<trkpt lat="([^"]+)" lon="([^"]+)">'
        matches = re.findall(pattern, content)
        for lat, lon in matches:
            points.append((lat, lon))
    return points

def generate_dart_code(points, route_name):
    """Genera código Dart para una lista de puntos"""
    dart_lines = []
    dart_lines.append(f"  static const List<LatLng> {route_name} = [")
    
    for lat, lon in points:
        dart_lines.append(f"    LatLng({lat}, {lon}),")
    
    dart_lines.append("  ];")
    return "\n".join(dart_lines)

# Parsear ambas rutas
print("Parseando aystocoy.gpx...")
ays_to_coy = parse_gpx('aystocoy.gpx')
print(f"Encontrados {len(ays_to_coy)} puntos en la ruta AYS->COY")

print("\nParseando coytoays.gpx...")
coy_to_ays = parse_gpx('coytoays.gpx')
print(f"Encontrados {len(coy_to_ays)} puntos en la ruta COY->AYS")

# Generar código Dart
print("\nGenerando código Dart...\n")
print("import 'package:latlong2/latlong.dart';")
print()
print("class RouteData {")
print("  // Ruta Aysén -> Coyhaique (Naranja)")
print(generate_dart_code(ays_to_coy, "routeAysToCoy"))
print()
print("  // Ruta Coyhaique -> Aysén (Celeste)")
print(generate_dart_code(coy_to_ays, "routeCoyToAys"))
print()
print("  // Mantener compatibilidad con código antiguo")
print("  static const List<LatLng> points = routeAysToCoy;")
print("}")
