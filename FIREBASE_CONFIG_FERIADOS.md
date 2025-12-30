# Configuración de Firebase para Sistema de Feriados

## Estructura de Colecciones

### 1. Colección: `feriados/{año}`

Ejemplo: `feriados/2025`

```json
{
  "01-01": {
    "nombre": "Año Nuevo",
    "activo": true,
    "tipoHorario": "sinServicio"
  },
  "12-25": {
    "nombre": "Navidad", 
    "activo": true,
    "tipoHorario": "especial"
  },
  "09-18": {
    "nombre": "Fiestas Patrias",
    "activo": true,
    "tipoHorario": "domingo"
  }
}
```

**Tipos de horario:**
- `domingo`: Usa horarios normales de la colección domingosFeriados
- `especial`: Usa horarios personalizados de horarios_especiales_feriados
- `sinServicio`: No hay servicio ese día

### 2. Colección: `horarios_especiales_feriados/{año}/{region}`

Ejemplo: `horarios_especiales_feriados/2025/aysen`

```json
{
  "feriado": "12-25",
  "time": "08:00"
}
```

Ejemplo: `horarios_especiales_feriados/2025/coyhaique`

```json
{
  "feriado": "12-25",
  "time": "09:30"
}
```

## Índices de Firestore Requeridos

Para que las consultas funcionen correctamente, debes crear estos índices en Firebase Console:

### Acceder a los índices:
https://console.firebase.google.com/project/suray-web/firestore/indexes

### Índices necesarios:

1. **Para aysen:**
   - Colección: `horarios_especiales_feriados/{año}/aysen`
   - Campo 1: `feriado` (Ascending)
   - Campo 2: `time` (Ascending)
   - Scope: Collection

2. **Para coyhaique:**
   - Colección: `horarios_especiales_feriados/{año}/coyhaique`
   - Campo 1: `feriado` (Ascending)
   - Campo 2: `time` (Ascending)
   - Scope: Collection

**NOTA:** Firebase puede crear estos índices automáticamente cuando los necesite. Si ves un error en la consola del navegador con un enlace, simplemente sigue el enlace para crear el índice.

## Reglas de Seguridad de Firestore

Asegúrate de que las reglas de Firebase permitan leer la nueva colección:

En Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ... reglas existentes ...
    
    // Regla para horarios especiales de feriados (SOLO LECTURA en web)
    match /horarios_especiales_feriados/{year}/{region}/{document=**} {
      allow read: if true;  // Permitir lectura pública
      allow write: if request.auth != null;  // Solo usuarios autenticados pueden escribir
    }
  }
}
```

## Pruebas y Validación

### Paso a paso para probar:

1. **Crear un feriado de cada tipo** en el panel de gestión (suraywebedit):
   - Feriado con horario de domingo (tipo: `domingo`)
   - Feriado con horario especial (tipo: `especial`) 
   - Feriado sin servicio (tipo: `sinServicio`)

2. **Para el feriado ESPECIAL**, agregar horarios personalizados:
   - Ir a "Horario Especial" desde la tarjeta del feriado
   - Agregar horarios diferentes para Aysén y Coyhaique

3. **Probar en la web**:
   - Navegar a la fecha del feriado tipo "domingo" → Debe mostrar horarios de domingo
   - Navegar a la fecha del feriado "especial" → Debe mostrar badge morado "HORARIO ESPECIAL" y horarios personalizados
   - Navegar a la fecha del feriado "sinServicio" → Debe mostrar ícono rojo y "Sin servicio por feriado"

4. **Verificar próximas salidas** en la página principal:
   - Si hoy es feriado sin servicio → "Sin servicio por feriado"
   - Si hoy es feriado especial → Muestra próxima salida de horarios especiales
   - Si hoy es feriado domingo → Muestra próxima salida de horarios de domingo

## Troubleshooting

### Problema: No se muestran los horarios especiales
**Solución:**
- Verificar que los índices de Firestore estén creados
- Verificar que los documentos en horarios_especiales_feriados tengan el campo 'feriado' correcto
- Revisar la consola del navegador para errores

### Problema: Error "Missing or insufficient permissions"
**Solución:**
- Verificar las reglas de Firestore
- Asegurarse de que la colección horarios_especiales_feriados tenga permisos de lectura

### Problema: Muestra "No hay horarios" en lugar de "Sin servicio"
**Solución:**
- Verificar que el feriado tenga tipoHorario: "sinServicio"
- Verificar que _getDayCollection() retorne 'sinServicio' correctamente

### Problema: No detecta que es feriado
**Solución:**
- Verificar que el formato de fecha en feriados sea "MM-DD" (con ceros a la izquierda)
- Ejemplo correcto: "01-01", "12-25"
- Ejemplo incorrecto: "1-1", "12-5"

## Resumen de Cambios Implementados

### ✅ home.dart:
- `_loadHolidays()`: Asegura tipoHorario en todos los feriados
- `_getDayCollection()`: Detecta tipo de feriado y retorna identificador apropiado
- `_listenToSchedule()`: Maneja horarios especiales y sin servicio
- `_findNextDepartureFromLists()`: Detecta "Sin servicio por feriado"

### ✅ schedules_page.dart:
- `_getDayCollection()`: Misma lógica que home.dart
- `_timesStream()`: Consulta colección correcta según tipo
- `_buildCityScheduleColumn()`: Badge morado para horarios especiales y mensaje rojo para sin servicio

### ✅ Firebase:
- Crear índices para horarios_especiales_feriados
- Actualizar reglas de seguridad para permitir lectura pública
