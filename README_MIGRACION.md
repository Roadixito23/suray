# Buses Suray - Migración Firebase → MySQL

[![Status](https://img.shields.io/badge/Status-Migración_Completa-success)]()
[![Backend](https://img.shields.io/badge/Backend-Node.js%2FExpress-green)]()
[![Database](https://img.shields.io/badge/Database-MySQL-blue)]()
[![Frontend](https://img.shields.io/badge/Frontend-Flutter-02569B)]()

## 🎯 Resumen

Este proyecto ha sido preparado para migrar de **Firebase/Firestore** a una base de datos **MySQL** con un backend **Node.js/Express**.

## 📂 Estructura del Proyecto

```
suray/
│
├── 📁 backend/                    # Backend API (Node.js/Express)
│   ├── src/
│   │   ├── config/                # Configuración de MySQL
│   │   ├── controllers/           # Lógica de negocio
│   │   ├── routes/                # Rutas de la API
│   │   ├── scripts/               # Script de migración
│   │   └── server.js              # Servidor principal
│   ├── .env.example               # Plantilla de variables de entorno
│   ├── package.json
│   ├── verify-setup.js            # Script de verificación
│   └── README.md
│
├── 📁 lib/
│   ├── services/
│   │   └── api_service.dart       # 🆕 Servicio HTTP para la API
│   ├── home_api.dart              # 🆕 Home migrado
│   ├── route_page_api.dart        # 🆕 Mapa de ruta migrado
│   ├── schedules_page_api.dart    # 🆕 Horarios migrados
│   └── ...                        # Archivos originales (Firebase)
│
├── 📁 scriptsql/
│   └── suray_web_serve.sql        # Script SQL para crear tablas
│
├── 📄 INICIO_RAPIDO.md            # ⭐ Guía de inicio rápido
├── 📄 MIGRATION_GUIDE.md          # 📖 Guía completa de migración
└── 📄 README_MIGRACION.md         # Este archivo
```

## 🚀 Inicio Rápido

### Opción 1: Inicio Rápido (Recomendado)

```bash
# 1. Lee la guía rápida
cat INICIO_RAPIDO.md
```

### Opción 2: Paso a Paso Completo

```bash
# 1. Configurar base de datos MySQL
# - Crear base de datos "suray_web_serve"
# - Ejecutar: scriptsql/suray_web_serve.sql

# 2. Configurar backend
cd backend
npm install
cp .env.example .env
# Editar .env con tus credenciales

# 3. Verificar configuración
npm run verify

# 4. Ejecutar servidor
npm run dev

# 5. Migrar datos de Firebase (opcional si ya tienes datos)
# Descargar firebase-service-account.json a backend/
npm run migrate
```

## 📚 Documentación

| Archivo | Descripción | Para quién |
|---------|-------------|-----------|
| [INICIO_RAPIDO.md](INICIO_RAPIDO.md) | Guía de 5 pasos para empezar | ⭐ Empezar aquí |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Guía completa y detallada | Referencia completa |
| [backend/README.md](backend/README.md) | Documentación de la API | Desarrollo del backend |

## 🔧 Tecnologías

### Backend
- **Node.js** 18+ (LTS recomendado)
- **Express.js** - Framework web
- **MySQL2** - Driver de MySQL
- **dotenv** - Gestión de variables de entorno
- **cors** - Manejo de CORS

### Frontend
- **Flutter** 3.7+
- **HTTP package** - Llamadas a la API
- Mantiene compatibilidad con Firebase (opcional)

### Base de Datos
- **MySQL** 5.7+ / 8.0+
- 3 tablas principales:
  - `horarios` - Horarios de buses
  - `feriados` - Días feriados
  - `ruta_estaciones` - Estaciones de la ruta

## 🔄 Proceso de Migración

```
┌─────────────┐
│  Firebase   │
│  (Antes)    │
└──────┬──────┘
       │
       │ Migración
       ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Flutter    │────▶│  API REST   │────▶│   MySQL     │
│    App      │     │ (Node.js)   │     │ (Tu hosting)│
└─────────────┘     └─────────────┘     └─────────────┘
```

## ✅ Checklist de Migración

- [ ] 1. Crear base de datos MySQL
- [ ] 2. Ejecutar script SQL
- [ ] 3. Configurar backend (.env)
- [ ] 4. Verificar configuración (`npm run verify`)
- [ ] 5. Probar backend localmente
- [ ] 6. Migrar datos de Firebase
- [ ] 7. Probar versiones `*_api.dart` en Flutter
- [ ] 8. Desplegar backend en producción
- [ ] 9. Actualizar URL de API en Flutter
- [ ] 10. Desplegar Flutter Web
- [ ] 11. (Opcional) Remover dependencias de Firebase

## 🌐 Endpoints de la API

### Horarios
```
GET    /api/horarios/:region/:tipo_dia  # Obtener horarios específicos
GET    /api/horarios/:region            # Obtener todos los horarios
POST   /api/horarios                    # Crear nuevo horario
DELETE /api/horarios/:id                # Eliminar horario
```

### Feriados
```
GET    /api/feriados/:anio              # Obtener feriados por año
POST   /api/feriados                    # Crear nuevo feriado
PUT    /api/feriados/:id                # Actualizar feriado
DELETE /api/feriados/:id                # Eliminar feriado
```

### Estaciones
```
GET    /api/estaciones                  # Obtener todas las estaciones
GET    /api/estaciones/:id              # Obtener estación por ID
POST   /api/estaciones                  # Crear nueva estación
PUT    /api/estaciones/:id              # Actualizar estación
DELETE /api/estaciones/:id              # Eliminar estación
```

### Health Check
```
GET    /health                          # Estado del servidor
```

## 🔍 Verificación de Setup

Antes de ejecutar el servidor, verifica que todo esté configurado correctamente:

```bash
cd backend
npm run verify
```

Este comando verifica:
- ✅ Archivo `.env` existe
- ✅ Variables de entorno configuradas
- ✅ Conexión a MySQL exitosa
- ✅ Tablas creadas
- ✅ Datos en las tablas
- ✅ Dependencias instaladas

## 🆚 Comparación: Antes vs Después

| Aspecto | Firebase (Antes) | MySQL + API (Después) |
|---------|------------------|----------------------|
| **Arquitectura** | Flutter → Firebase | Flutter → API → MySQL |
| **Tiempo Real** | ✅ Streams | ⏰ Polling (5 min) |
| **Costo** | Variable (uso) | Fijo (hosting) |
| **Control Datos** | Limitado | Total |
| **Consultas** | Limitadas | SQL completo |
| **Offline** | SDK incluido | Requiere implementación |
| **Escalabilidad** | Automática | Manual |
| **Dependencias** | Firebase SDK | HTTP estándar |

## 🐛 Solución de Problemas

### Backend no se conecta a MySQL
```bash
# Verificar credenciales
nano backend/.env

# Verificar que MySQL esté corriendo
# En Windows: servicios de Windows
# En Linux/Mac: systemctl status mysql
```

### CORS bloqueado en Flutter Web
```bash
# Editar backend/.env
CORS_ORIGIN=http://localhost:8080  # O tu dominio
```

### Los datos no se actualizan
- La app actualiza cada 5 minutos (no es tiempo real)
- Puedes ajustar el intervalo en `home_api.dart`
- O agregar un botón de recarga manual

## 📦 Despliegue

### Backend en Producción

**Opción A: Hosting con Node.js (PM2)**
```bash
npm install -g pm2
pm2 start src/server.js --name suray-api
pm2 save
pm2 startup
```

**Opción B: Servicios Cloud**
- Heroku
- Railway
- Render
- DigitalOcean App Platform

### Flutter Web en Producción

```bash
flutter build web --release
# Subir carpeta build/web/ a tu hosting
```

## 🔐 Seguridad

**Importante:**
- ❌ **NO** versionar el archivo `.env`
- ❌ **NO** versionar `firebase-service-account.json`
- ✅ Usar variables de entorno en producción
- ✅ Habilitar HTTPS en producción
- ✅ Configurar CORS correctamente

## 📈 Próximas Mejoras (Opcional)

- [ ] Agregar autenticación JWT
- [ ] Implementar rate limiting
- [ ] Agregar logs persistentes
- [ ] Implementar caché (Redis)
- [ ] Crear panel de administración
- [ ] Agregar notificaciones push
- [ ] Implementar WebSockets para tiempo real

## 🤝 Contribución

Si encuentras bugs o quieres mejorar el código:
1. Crea un backup antes de hacer cambios
2. Documenta los cambios
3. Prueba en desarrollo antes de producción

## 📝 Notas Importantes

1. **Los archivos `*_api.dart` son las versiones migradas**
   - `home_api.dart` → Usa API en lugar de Firebase
   - `route_page_api.dart` → Usa API en lugar de Firebase
   - `schedules_page_api.dart` → Usa API en lugar de Firebase

2. **Los archivos originales siguen funcionando con Firebase**
   - Puedes probar ambas versiones
   - Decide cuándo hacer el switch completo

3. **El backend es completamente independiente**
   - Puede correr en tu hosting o en un servicio cloud
   - La app Flutter solo necesita la URL de la API

## 📞 Soporte

Si tienes problemas:
1. Lee [INICIO_RAPIDO.md](INICIO_RAPIDO.md)
2. Consulta [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
3. Revisa los logs del backend
4. Verifica la consola del navegador (Flutter Web)

---

**Estado del Proyecto**: ✅ Listo para migración

**Última actualización**: Diciembre 2025

**Versión**: 1.0.0
