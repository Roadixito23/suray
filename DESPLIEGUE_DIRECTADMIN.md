# Guía de Despliegue en DirectAdmin con Node.js

## 📋 Resumen

Tu hosting tiene soporte para Node.js a través de "Setup Node.js App". Esta guía te muestra cómo desplegar el backend.

---

## Fase 1: Desarrollo Local (AHORA)

### 1. Instalar XAMPP

1. **Descargar XAMPP**: [https://www.apachefriends.org/es/download.html](https://www.apachefriends.org/es/download.html)
2. **Instalar** y ejecutar **XAMPP Control Panel**
3. **Iniciar MySQL** (clic en "Start" junto a MySQL)

### 2. Crear Base de Datos Local

1. Abre `http://localhost/phpmyadmin` en tu navegador
2. Clic en "Nueva" para crear base de datos
3. Nombre: `suray_web_serve`
4. Collation: `utf8mb4_unicode_ci`
5. Clic en "Crear"

### 3. Ejecutar el Script SQL

1. Selecciona la base de datos `suray_web_serve`
2. Ve a la pestaña "SQL"
3. Copia y pega el contenido de `scriptsql/suray_web_serve.sql`
4. Clic en "Continuar"

### 4. Probar el Backend Localmente

```bash
cd backend

# Verificar configuración
npm run verify

# Debería mostrar:
# ✅ Conexión a MySQL exitosa
# ✅ Todas las tablas existen

# Migrar datos de Firebase
npm run migrate

# Ejecutar servidor
npm run dev

# Debería mostrar:
# 🚌 Suray API Server
# Puerto: 3000
```

### 5. Probar en el Navegador

Abre: `http://localhost:3000`

Deberías ver información de la API.

---

## Fase 2: Despliegue en Producción (DESPUÉS)

### 1. Acceder a "Setup Node.js App" en DirectAdmin

1. Entra a tu **DirectAdmin**
2. Ve a **"Setup Node.js App"** (en CARACTERÍSTICAS EXTRAS)
3. Haz clic para configurar

### 2. Configurar la Aplicación Node.js

Completa el formulario:

- **Application Root**: `/home/suraycl1/backend` (o la ruta donde subirás el código)
- **Application URL**: `https://api.tudominio.com` (o un subdominio)
- **Application Startup File**: `src/server.js`
- **Node.js Version**: Selecciona la más reciente (18.x o 20.x)
- **Mode**: Production

### 3. Subir los Archivos del Backend

Usando FTP o el administrador de archivos de DirectAdmin:

1. Sube la carpeta `backend/` a tu servidor
2. Estructura debe quedar:
   ```
   /home/suraycl1/backend/
   ├── src/
   ├── package.json
   ├── .env
   └── ...
   ```

### 4. Configurar Variables de Entorno en Producción

**IMPORTANTE**: En el servidor, el archivo `.env` debe tener:

```env
# Configuración PRODUCCIÓN
PORT=3000
NODE_ENV=production

# MySQL en el MISMO SERVIDOR
DB_HOST=localhost
DB_USER=suraycl1_suray_web_server
DB_PASSWORD=tJtHQgqs86258mZDDhtw
DB_NAME=suraycl1_suray_web_server
DB_PORT=3306

# CORS (tu dominio real)
CORS_ORIGIN=https://tudominio.com

# Firebase
FIREBASE_PROJECT_ID=suray-web
```

**Puedes copiar el archivo `.env.production` que creé:**
```bash
# En el servidor (por SSH o terminal de DirectAdmin)
cp .env.production .env
```

### 5. Instalar Dependencias en el Servidor

Usando SSH o terminal de DirectAdmin:

```bash
cd ~/backend
npm install --production
```

### 6. Iniciar la Aplicación

En DirectAdmin, en "Setup Node.js App":
- Haz clic en **"Restart"** o **"Start"**

### 7. Configurar Dominio/Subdominio (Opcional)

Para acceder a la API desde `https://api.tudominio.com`:

1. En DirectAdmin, ve a **"Subdominios"**
2. Crea subdominio: `api.tudominio.com`
3. En "Setup Node.js App", configura el proxy reverso hacia el puerto de Node.js (generalmente 3000)

---

## Fase 3: Actualizar Flutter para usar la API en Producción

### 1. Cambiar URL en Flutter

Edita `lib/services/api_service.dart`:

```dart
class ApiService {
  // PRODUCCIÓN
  static const String _baseUrl = 'https://api.tudominio.com/api';

  // O si no usas subdominio:
  // static const String _baseUrl = 'https://tudominio.com:3000/api';
}
```

### 2. Reemplazar Archivos Firebase por Versiones API

```bash
# Hacer backup
mv lib/home.dart lib/home_firebase_backup.dart
mv lib/route_page.dart lib/route_page_firebase_backup.dart
mv lib/schedules_page.dart lib/schedules_page_firebase_backup.dart

# Usar versiones API
mv lib/home_api.dart lib/home.dart
mv lib/route_page_api.dart lib/route_page.dart
mv lib/schedules_page_api.dart lib/schedules_page.dart
```

### 3. Compilar Flutter

```bash
flutter build web --release
```

### 4. Subir Flutter Web al Hosting

Sube el contenido de `build/web/` a la carpeta `public_html/` de tu hosting.

---

## 📊 Arquitectura Final

```
┌─────────────────┐
│  Usuario Web    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Flutter Web    │ (tudominio.com)
│  public_html/   │
└────────┬────────┘
         │ HTTP
         ▼
┌─────────────────┐
│   API REST      │ (api.tudominio.com:3000)
│   Node.js       │
│   ~/backend/    │
└────────┬────────┘
         │ SQL
         ▼
┌─────────────────┐
│     MySQL       │ (localhost:3306)
│  Base de Datos  │
└─────────────────┘

TODO EN EL MISMO SERVIDOR ✅
```

---

## ✅ Checklist de Despliegue

### Desarrollo Local
- [ ] Instalar XAMPP
- [ ] Crear base de datos `suray_web_serve`
- [ ] Ejecutar script SQL
- [ ] Configurar `.env` para local
- [ ] `npm run verify` exitoso
- [ ] `npm run migrate` completado
- [ ] `npm run dev` funcionando
- [ ] API responde en `http://localhost:3000`

### Producción
- [ ] Subir carpeta `backend/` al servidor
- [ ] Configurar `.env` para producción
- [ ] Instalar dependencias (`npm install --production`)
- [ ] Configurar "Setup Node.js App"
- [ ] Iniciar aplicación
- [ ] API responde desde el dominio
- [ ] Actualizar URL en Flutter
- [ ] Reemplazar archivos Firebase por API
- [ ] Compilar y subir Flutter Web
- [ ] Probar toda la aplicación

---

## 🆘 Problemas Comunes

### "npm install" falla en el servidor
- Verifica que Node.js esté instalado: `node --version`
- Usa `npm install --production` para evitar dependencias de desarrollo

### La API no responde
- Verifica que el puerto 3000 esté abierto
- Revisa logs en DirectAdmin
- Verifica que la aplicación esté corriendo

### Error de CORS
- Actualiza `CORS_ORIGIN` en `.env` con tu dominio real
- Reinicia la aplicación Node.js

### Base de datos no conecta
- En producción, `DB_HOST` DEBE ser `localhost` (mismo servidor)
- Verifica que las credenciales sean correctas
- Verifica que la base de datos exista

---

## 📞 Próximos Pasos

1. **Ahora**: Instala XAMPP y configura todo localmente
2. **Prueba**: Verifica que todo funcione en tu computadora
3. **Luego**: Sube el backend al hosting
4. **Finalmente**: Actualiza Flutter y despliega

¿Necesitas ayuda con algún paso? Avísame.
