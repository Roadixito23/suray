# Script para parsear archivos GPX y generar código Dart

function Parse-GPX {
    param($filename)
    
    $content = Get-Content $filename -Raw
    $pattern = '<trkpt lat="([^"]+)" lon="([^"]+)">'
    $matches = [regex]::Matches($content, $pattern)
    
    $points = @()
    foreach ($match in $matches) {
        $lat = $match.Groups[1].Value
        $lon = $match.Groups[2].Value
        $points += @{lat=$lat; lon=$lon}
    }
    
    return $points
}

function Generate-DartCode {
    param($points, $routeName)
    
    $code = "  static const List<LatLng> $routeName = [`n"
    
    foreach ($point in $points) {
        $code += "    LatLng($($point.lat), $($point.lon)),`n"
    }
    
    $code += "  ];`n"
    return $code
}

Write-Host "Parseando aystocoy.gpx..."
$aysToCoy = Parse-GPX "aystocoy.gpx"
Write-Host "Encontrados $($aysToCoy.Count) puntos en la ruta AYS->COY"

Write-Host "`nParseando coytoays.gpx..."
$coyToAys = Parse-GPX "coytoays.gpx"
Write-Host "Encontrados $($coyToAys.Count) puntos en la ruta COY->AYS"

Write-Host "`nGenerando código Dart...`n"

$dartCode = @"
import 'package:latlong2/latlong.dart';

class RouteData {
  // Ruta Aysén -> Coyhaique (Naranja)
$(Generate-DartCode $aysToCoy "routeAysToCoy")

  // Ruta Coyhaique -> Aysén (Celeste)
$(Generate-DartCode $coyToAys "routeCoyToAys")

  // Mantener compatibilidad con código antiguo
  static const List<LatLng> points = routeAysToCoy;
}
"@

$dartCode | Out-File -FilePath "route_output.dart" -Encoding UTF8
Write-Host "Código generado en route_output.dart"
