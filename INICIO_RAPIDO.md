# 🚀 Inicio Rápido - Migración Firebase a MySQL

Guía resumida para empezar con la migración. Para detalles completos, consulta [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md).

## ✅ Lo que ya está listo

He creado toda la infraestructura necesaria para migrar de Firebase a MySQL:

- ✅ **Backend completo** (Node.js/Express) en la carpeta `backend/`
- ✅ **API REST** con endpoints para horarios, feriados y estaciones
- ✅ **Servicio HTTP** en Flutter (`lib/services/api_service.dart`)
- ✅ **Versiones migradas** de tus páginas principales:
  - `lib/home_api.dart`
  - `lib/route_page_api.dart`
  - `lib/schedules_page_api.dart`
- ✅ **Script de migración** de datos de Firebase a MySQL
- ✅ **Script SQL** para crear las tablas en MySQL

## 📋 Pasos para empezar

### 1. Configurar MySQL (5 minutos)

```bash
# En phpMyAdmin o tu gestor de base de datos:
# 1. Crear base de datos "suray_web_serve"
# 2. Ejecutar el script: scriptsql/suray_web_serve.sql
```

### 2. Configurar el Backend (5 minutos)

```bash
cd backend

# Instalar dependencias
npm install

# Configurar credenciales
cp .env.example .env
# Editar .env con tus credenciales de MySQL

# Probar el servidor
npm run dev
```

Deberías ver:
```
╔═══════════════════════════════════════╗
║     🚌 Suray API Server               ║
║     Puerto: 3000                       ║
╚═══════════════════════════════════════╝
```

### 3. Migrar los Datos (10 minutos)

```bash
# Descargar credenciales de Firebase Admin SDK
# y guardarlas como: backend/firebase-service-account.json

# Ejecutar migración
npm run migrate
```

### 4. Probar la App Flutter (5 minutos)

```bash
# En otra terminal, desde la raíz del proyecto

# Ejecutar Flutter Web
flutter run -d chrome
```

La app seguirá funcionando con Firebase por ahora.

### 5. Cambiar a la Versión API (2 minutos)

Para probar la versión con API, edita `lib/splash.dart`:

```dart
// Cambiar esta línea:
import 'home.dart';

// Por esta:
import 'home_api.dart';
```

Reinicia la app y verifica que todo funcione.

## 🔧 Configuración de Producción

### URL de la API

Edita `lib/services/api_service.dart`:

```dart
// Desarrollo:
static const String _baseUrl = 'http://localhost:3000/api';

// Producción:
static const String _baseUrl = 'https://tu-dominio.com/api';
```

### CORS

Edita `backend/.env`:

```env
# Desarrollo:
CORS_ORIGIN=http://localhost:8080

# Producción:
CORS_ORIGIN=https://tu-dominio.com
```

## 📊 Estructura de la API

### Horarios
```
GET  /api/horarios/:region/:tipo_dia
GET  /api/horarios/:region
POST /api/horarios
```

### Feriados
```
GET  /api/feriados/:anio
POST /api/feriados
```

### Estaciones
```
GET  /api/estaciones
GET  /api/estaciones/:id
POST /api/estaciones
```

## 🆘 Solución Rápida de Problemas

### "Cannot connect to MySQL"
→ Verifica credenciales en `backend/.env`

### "CORS policy blocked"
→ Agrega tu dominio en `CORS_ORIGIN`

### "Network request failed"
→ Verifica que el backend esté corriendo en `http://localhost:3000`

### Los datos no se actualizan
→ La app actualiza cada 5 minutos (ya no es tiempo real como Firebase)

## 📚 Archivos Importantes

| Archivo | Descripción |
|---------|-------------|
| `backend/src/server.js` | Servidor principal |
| `backend/src/config/database.js` | Conexión MySQL |
| `backend/src/routes/` | Rutas de la API |
| `lib/services/api_service.dart` | Servicio HTTP Flutter |
| `lib/*_api.dart` | Páginas migradas |
| `MIGRATION_GUIDE.md` | Guía completa |

## ✨ Próximos Pasos

1. ✅ Configurar base de datos
2. ✅ Probar backend localmente
3. ✅ Migrar datos
4. ✅ Probar versiones `*_api.dart`
5. ⏳ Desplegar backend en producción
6. ⏳ Actualizar app con URL de producción
7. ⏳ Reemplazar archivos originales por versiones `*_api.dart`

## 🎯 Comparación Rápida

| | Firebase | MySQL + API |
|---|---------|-------------|
| **Configuración** | Automática | Manual |
| **Costo** | Variable | Fijo (hosting) |
| **Tiempo real** | Sí | No (polling) |
| **Control** | Limitado | Total |
| **SQL** | No | Sí |

---

¿Necesitas ayuda? Consulta [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) para más detalles.
