const express = require('express');
const cors = require('cors');
require('dotenv').config();

const horariosRoutes = require('./routes/horarios');
const feriadosRoutes = require('./routes/feriados');
const estacionesRoutes = require('./routes/estaciones');

const app = express();
const PORT = process.env.PORT || 3000;

// Middlewares
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*'
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logger simple
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Rutas de la API
app.use('/api/horarios', horariosRoutes);
app.use('/api/feriados', feriadosRoutes);
app.use('/api/estaciones', estacionesRoutes);

// Ruta de health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Ruta raíz
app.get('/', (req, res) => {
  res.json({
    name: 'Suray API',
    version: '1.0.0',
    endpoints: {
      horarios: '/api/horarios/:region/:tipo_dia',
      feriados: '/api/feriados/:anio',
      estaciones: '/api/estaciones'
    }
  });
});

// Manejo de errores 404
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Manejo de errores generales
app.use((err, req, res, next) => {
  console.error('Error no manejado:', err);
  res.status(500).json({
    error: 'Error interno del servidor',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════╗
║     🚌 Suray API Server               ║
║     Puerto: ${PORT}                       ║
║     Entorno: ${process.env.NODE_ENV || 'development'}         ║
╚═══════════════════════════════════════╝
  `);
  console.log(`API disponible en http://localhost:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;
