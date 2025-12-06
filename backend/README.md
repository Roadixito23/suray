# Suray API Backend

API REST para la aplicación Buses Suray. Conecta con base de datos MySQL y reemplaza Firebase.

## Instalación

1. Instalar dependencias:
```bash
cd backend
npm install
```

2. Configurar variables de entorno:
```bash
cp .env.example .env
```

Editar el archivo `.env` con tus credenciales de base de datos:
```env
DB_HOST=tu_host
DB_USER=tu_usuario
DB_PASSWORD=tu_contraseña
DB_NAME=suray_web_serve
```

3. Crear las tablas en la base de datos:
```bash
# Ejecutar el script SQL en tu base de datos
mysql -u tu_usuario -p suray_web_serve < ../scriptsql/suray_web_serve.sql
```

## Uso

### Modo desarrollo (con auto-reload):
```bash
npm run dev
```

### Modo producción:
```bash
npm start
```

El servidor estará disponible en `http://localhost:3000`

## Endpoints de la API

### Horarios

- **GET** `/api/horarios/:region/:tipo_dia` - Obtener horarios específicos
  - Ejemplo: `/api/horarios/aysen/lunesViernes`
  - Regiones: `aysen`, `coyhaique`
  - Tipos: `lunesViernes`, `sabados`, `domingosFeriados`

- **GET** `/api/horarios/:region` - Obtener todos los horarios de una región
  - Ejemplo: `/api/horarios/coyhaique`

- **POST** `/api/horarios` - Crear nuevo horario
  ```json
  {
    "region": "aysen",
    "tipo_dia": "lunesViernes",
    "hora": "08:30"
  }
  ```

- **DELETE** `/api/horarios/:id` - Eliminar horario (soft delete)

### Feriados

- **GET** `/api/feriados/:anio` - Obtener feriados por año
  - Ejemplo: `/api/feriados/2025`

- **POST** `/api/feriados` - Crear nuevo feriado
  ```json
  {
    "anio": 2025,
    "mes": 12,
    "dia": 25,
    "nombre": "Navidad",
    "activo": true
  }
  ```

- **PUT** `/api/feriados/:id` - Actualizar feriado
- **DELETE** `/api/feriados/:id` - Eliminar feriado (soft delete)

### Estaciones

- **GET** `/api/estaciones` - Obtener todas las estaciones activas
- **GET** `/api/estaciones/:id` - Obtener estación por ID
- **POST** `/api/estaciones` - Crear nueva estación
  ```json
  {
    "id": "est_01",
    "name": "Terminal",
    "fullName": "Terminal de Buses",
    "km": 0,
    "side": "center",
    "isTerminal": true,
    "orden": 0
  }
  ```

- **PUT** `/api/estaciones/:id` - Actualizar estación
- **DELETE** `/api/estaciones/:id` - Eliminar estación (soft delete)

### Health Check

- **GET** `/health` - Estado del servidor

## Migración de datos desde Firebase

Para migrar los datos existentes de Firebase a MySQL:

```bash
npm run migrate
```

**Nota:** Necesitarás el archivo de credenciales de Firebase Admin SDK (`firebase-service-account.json`) en la carpeta `backend/`.

## Estructura del proyecto

```
backend/
├── src/
│   ├── config/
│   │   └── database.js          # Configuración de conexión MySQL
│   ├── controllers/
│   │   ├── horariosController.js
│   │   ├── feriadosController.js
│   │   └── estacionesController.js
│   ├── routes/
│   │   ├── horarios.js
│   │   ├── feriados.js
│   │   └── estaciones.js
│   └── server.js                # Servidor principal
├── .env                         # Variables de entorno (no versionar)
├── .env.example                 # Ejemplo de variables de entorno
└── package.json
```

## Despliegue en producción

### Configurar variables de entorno en el servidor:
```env
NODE_ENV=production
PORT=3000
DB_HOST=tu_host_produccion
DB_USER=tu_usuario_produccion
DB_PASSWORD=tu_contraseña_produccion
DB_NAME=suray_web_serve
CORS_ORIGIN=https://tu-dominio.com
```

### Ejecutar en producción:
```bash
npm start
```

Para mantener el servidor corriendo, se recomienda usar PM2:
```bash
npm install -g pm2
pm2 start src/server.js --name suray-api
pm2 save
pm2 startup
```
