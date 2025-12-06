# Guía de Migración de Firebase a MySQL

Esta guía te ayudará a migrar tu aplicación de Buses Suray de Firebase/Firestore a una base de datos MySQL usando tu propio hosting.

## Índice

1. [Resumen de Cambios](#resumen-de-cambios)
2. [Estructura del Proyecto](#estructura-del-proyecto)
3. [Paso 1: Configurar la Base de Datos MySQL](#paso-1-configurar-la-base-de-datos-mysql)
4. [Paso 2: Configurar y Ejecutar el Backend](#paso-2-configurar-y-ejecutar-el-backend)
5. [Paso 3: Migrar los Datos de Firebase](#paso-3-migrar-los-datos-de-firebase)
6. [Paso 4: Actualizar la Aplicación Flutter](#paso-4-actualizar-la-aplicación-flutter)
7. [Paso 5: Despliegue en Producción](#paso-5-despliegue-en-producción)
8. [Solución de Problemas](#solución-de-problemas)

---

## Resumen de Cambios

### Qué cambia

- **Antes**: Firebase/Firestore (base de datos NoSQL en la nube)
- **Después**: MySQL (base de datos SQL en tu hosting) + API REST (Node.js/Express)

### Por qué esta arquitectura

1. **Flutter App** → **API REST** → **Base de Datos MySQL**
2. La app Flutter ya no se conecta directamente a Firebase
3. Todas las operaciones pasan por la API REST
4. La API se encarga de consultar y manipular la base de datos MySQL

### Ventajas

- ✅ Control total sobre tus datos
- ✅ Costos predecibles (tu hosting)
- ✅ Mayor flexibilidad para consultas SQL complejas
- ✅ Fácil de integrar con otros sistemas

---

## Estructura del Proyecto

```
suray/
├── backend/                      # Nuevo backend API
│   ├── src/
│   │   ├── config/
│   │   │   └── database.js      # Configuración MySQL
│   │   ├── controllers/         # Lógica de negocio
│   │   │   ├── horariosController.js
│   │   │   ├── feriadosController.js
│   │   │   └── estacionesController.js
│   │   ├── routes/              # Rutas de la API
│   │   │   ├── horarios.js
│   │   │   ├── feriados.js
│   │   │   └── estaciones.js
│   │   ├── scripts/
│   │   │   └── migrate-from-firebase.js  # Script de migración
│   │   └── server.js            # Servidor principal
│   ├── .env.example             # Ejemplo de variables de entorno
│   ├── package.json
│   └── README.md
│
├── lib/
│   ├── services/
│   │   └── api_service.dart     # Servicio HTTP para la API
│   ├── home_api.dart            # Home migrado (usa API)
│   ├── route_page_api.dart      # Mapa de ruta migrado (usa API)
│   └── schedules_page_api.dart  # Horarios migrados (usa API)
│
├── scriptsql/
│   └── suray_web_serve.sql      # Script de creación de tablas
│
└── MIGRATION_GUIDE.md           # Esta guía
```

---

## Paso 1: Configurar la Base de Datos MySQL

### 1.1. Acceder a tu hosting

Accede al panel de control de tu hosting (cPanel, Plesk, etc.)

### 1.2. Crear la base de datos

1. Ve a "MySQL Databases" o "Bases de Datos MySQL"
2. Crea una nueva base de datos llamada `suray_web_serve`
3. Crea un usuario con permisos completos sobre esa base de datos
4. **Guarda las credenciales**:
   - Host (generalmente `localhost` o una IP)
   - Usuario
   - Contraseña
   - Nombre de la base de datos
   - Puerto (generalmente `3306`)

### 1.3. Ejecutar el script SQL

1. Abre phpMyAdmin o el gestor de bases de datos de tu hosting
2. Selecciona la base de datos `suray_web_serve`
3. Ve a la pestaña "SQL" o "Importar"
4. Ejecuta el contenido del archivo `scriptsql/suray_web_serve.sql`

Esto creará 3 tablas:
- `horarios` - Horarios de buses
- `feriados` - Días feriados
- `ruta_estaciones` - Estaciones de la ruta

---

## Paso 2: Configurar y Ejecutar el Backend

### 2.1. Instalar Node.js

Si no tienes Node.js instalado:
- Descarga desde [nodejs.org](https://nodejs.org) (versión LTS recomendada)
- Verifica la instalación: `node --version` y `npm --version`

### 2.2. Instalar dependencias

```bash
cd backend
npm install
```

### 2.3. Configurar variables de entorno

```bash
# Copiar el archivo de ejemplo
cp .env.example .env
```

Edita el archivo `.env` con tus credenciales:

```env
# Configuración del servidor
PORT=3000
NODE_ENV=development

# Configuración de la base de datos MySQL
DB_HOST=localhost          # O la IP de tu servidor MySQL
DB_USER=tu_usuario         # Usuario de la base de datos
DB_PASSWORD=tu_contraseña  # Contraseña de la base de datos
DB_NAME=suray_web_serve    # Nombre de la base de datos
DB_PORT=3306               # Puerto de MySQL

# CORS - Dominio permitido
CORS_ORIGIN=http://localhost:8080  # Para desarrollo local

# Firebase (solo para migración de datos)
FIREBASE_PROJECT_ID=tu_proyecto_id
```

### 2.4. Probar el servidor en local

```bash
# Modo desarrollo (con auto-reload)
npm run dev
```

El servidor debería iniciarse en `http://localhost:3000`

Prueba abriendo en tu navegador:
- `http://localhost:3000` - Información de la API
- `http://localhost:3000/health` - Estado del servidor

---

## Paso 3: Migrar los Datos de Firebase

### 3.1. Descargar credenciales de Firebase Admin SDK

1. Ve a la [Consola de Firebase](https://console.firebase.google.com)
2. Selecciona tu proyecto
3. Ve a "Configuración del proyecto" (⚙️) > "Cuentas de servicio"
4. Haz clic en "Generar nueva clave privada"
5. Descarga el archivo JSON
6. Renómbralo a `firebase-service-account.json`
7. Colócalo en la carpeta `backend/`

**IMPORTANTE**: Este archivo contiene credenciales sensibles. **NO lo versiones en Git**.

### 3.2. Ejecutar la migración

```bash
cd backend
npm run migrate
```

Este script:
1. Se conecta a Firebase
2. Lee todos los horarios, feriados y estaciones
3. Los inserta en tu base de datos MySQL
4. Muestra un resumen de los datos migrados

### 3.3. Verificar la migración

Accede a phpMyAdmin y revisa que las tablas tengan datos:

```sql
-- Ver horarios
SELECT * FROM horarios LIMIT 10;

-- Ver feriados
SELECT * FROM feriados WHERE anio = 2025;

-- Ver estaciones
SELECT * FROM ruta_estaciones ORDER BY km;
```

---

## Paso 4: Actualizar la Aplicación Flutter

### 4.1. Configurar la URL de la API

Edita el archivo `lib/services/api_service.dart`:

```dart
class ApiService {
  // Para desarrollo local
  static const String _baseUrl = 'http://localhost:3000/api';

  // Para producción, cambia a la URL de tu servidor:
  // static const String _baseUrl = 'https://tu-dominio.com/api';

  // ...
}
```

### 4.2. Probar la migración en desarrollo

He creado versiones migradas de los archivos principales:

- `lib/home_api.dart` - Página principal (usa API)
- `lib/route_page_api.dart` - Mapa de ruta (usa API)
- `lib/schedules_page_api.dart` - Horarios (usa API)

**Opción A: Probar antes de reemplazar (recomendado)**

Temporalmente, modifica `lib/splash.dart` para usar las versiones `_api`:

```dart
// Importar las versiones API
import 'home_api.dart';  // En lugar de 'home.dart'

// En la navegación, usa HomePage de home_api.dart
```

Prueba la app y verifica que todo funcione correctamente.

**Opción B: Reemplazar directamente**

Una vez que confirmes que todo funciona, puedes:

1. Hacer backup de los archivos originales:
```bash
mv lib/home.dart lib/home_firebase_backup.dart
mv lib/route_page.dart lib/route_page_firebase_backup.dart
mv lib/schedules_page.dart lib/schedules_page_firebase_backup.dart
```

2. Renombrar los archivos nuevos:
```bash
mv lib/home_api.dart lib/home.dart
mv lib/route_page_api.dart lib/route_page.dart
mv lib/schedules_page_api.dart lib/schedules_page.dart
```

3. Actualizar las importaciones en todos los archivos que los usan

### 4.3. Remover dependencias de Firebase (opcional)

Una vez que confirmes que la migración funciona, puedes remover Firebase:

1. Edita `pubspec.yaml` y comenta/elimina:
```yaml
# firebase_core: ^2.13.0
# cloud_firestore: ^4.9.0
```

2. Elimina código de inicialización de Firebase en `lib/main.dart`:
```dart
// await Firebase.initializeApp(...); // Comentar o eliminar
```

3. Ejecuta:
```bash
flutter pub get
flutter clean
flutter pub get
```

---

## Paso 5: Despliegue en Producción

### 5.1. Desplegar el Backend en tu hosting

#### Opción A: Servidor Node.js con PM2

Si tu hosting soporta Node.js:

```bash
# Instalar PM2 globalmente
npm install -g pm2

# Subir la carpeta backend/ a tu servidor
# Luego en el servidor:

cd backend
npm install --production

# Configurar variables de entorno de producción
nano .env  # Editar con los valores de producción

# Iniciar con PM2
pm2 start src/server.js --name suray-api
pm2 save
pm2 startup  # Seguir las instrucciones para auto-inicio
```

#### Opción B: Usar un servicio cloud

Alternativas si tu hosting no soporta Node.js:
- [Heroku](https://www.heroku.com) (gratis para desarrollo)
- [Railway](https://railway.app)
- [Render](https://render.com)
- [DigitalOcean App Platform](https://www.digitalocean.com/products/app-platform)

### 5.2. Configurar CORS para producción

En `backend/.env`:

```env
CORS_ORIGIN=https://tu-dominio.com
```

Si tu app Flutter Web está en `https://miapp.com`, pon ese dominio.

### 5.3. Actualizar la URL de la API en Flutter

En `lib/services/api_service.dart`:

```dart
static const String _baseUrl = 'https://api.tu-dominio.com/api';
```

### 5.4. Compilar y desplegar Flutter Web

```bash
flutter build web --release
```

Los archivos compilados estarán en `build/web/`. Súbelos a tu hosting web.

---

## Solución de Problemas

### Error: "Cannot connect to MySQL"

**Causa**: Credenciales incorrectas o MySQL no está corriendo

**Solución**:
1. Verifica las credenciales en `.env`
2. Asegúrate de que MySQL esté corriendo
3. Verifica el firewall (puerto 3306 debe estar abierto)

### Error: "CORS policy blocked"

**Causa**: El dominio de tu app no está permitido en el backend

**Solución**:
1. Agrega tu dominio a `CORS_ORIGIN` en `.env`
2. O usa `*` para permitir todos (solo en desarrollo):
```env
CORS_ORIGIN=*
```

### Error: "Network request failed" en Flutter

**Causa**: La URL de la API es incorrecta o el servidor no está corriendo

**Solución**:
1. Verifica que el backend esté corriendo
2. Verifica la URL en `lib/services/api_service.dart`
3. En desarrollo web, usa `http://localhost:3000` (no `127.0.0.1`)

### Los horarios no se actualizan en tiempo real

**Nota**: A diferencia de Firebase que tiene streams en tiempo real, la API usa polling.

**Solución**:
- La app actualiza los datos cada 5 minutos automáticamente
- Puedes ajustar este intervalo en `home_api.dart`:
```dart
_dataRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
  _loadScheduleData();
});
```

### Error durante la migración de datos

**Causa**: Problemas con las credenciales de Firebase o estructura de datos

**Solución**:
1. Verifica que `firebase-service-account.json` esté en `backend/`
2. Verifica que el `FIREBASE_PROJECT_ID` en `.env` sea correcto
3. Revisa los logs para ver qué datos fallan
4. Puedes ejecutar la migración múltiples veces (usa `ON DUPLICATE KEY UPDATE`)

---

## Comparación: Firebase vs MySQL

| Aspecto | Firebase | MySQL + API |
|---------|----------|-------------|
| **Streams en tiempo real** | ✅ Sí | ❌ No (usa polling) |
| **Costo** | Escala con uso | Fijo (hosting) |
| **Control de datos** | Limitado | Total |
| **Consultas complejas** | Limitado | SQL completo |
| **Offline** | Sí (SDK) | Requiere implementación |
| **Mantenimiento** | Mínimo | Medio |

---

## Próximos Pasos

1. ✅ Configurar base de datos MySQL
2. ✅ Configurar y probar backend localmente
3. ✅ Migrar datos de Firebase
4. ✅ Probar app Flutter con las versiones `_api`
5. ✅ Desplegar backend en producción
6. ✅ Actualizar Flutter con URL de producción
7. ✅ Desplegar Flutter Web
8. ⏳ (Opcional) Remover dependencias de Firebase
9. ⏳ Monitorear y optimizar

---

## Soporte

Si encuentras problemas durante la migración:

1. Revisa los logs del backend: `pm2 logs suray-api` (si usas PM2)
2. Revisa la consola del navegador en Flutter Web
3. Verifica las credenciales y configuración
4. Consulta los archivos README en las carpetas `backend/` y raíz del proyecto

---

¡Buena suerte con la migración! 🚀
