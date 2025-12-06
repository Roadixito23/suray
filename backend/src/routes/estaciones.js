const express = require('express');
const router = express.Router();
const estacionesController = require('../controllers/estacionesController');

// Obtener todas las estaciones
router.get('/', estacionesController.getAllEstaciones);

// Obtener estación por ID
router.get('/:id', estacionesController.getEstacionById);

// Crear nueva estación
router.post('/', estacionesController.createEstacion);

// Actualizar estación
router.put('/:id', estacionesController.updateEstacion);

// Eliminar estación
router.delete('/:id', estacionesController.deleteEstacion);

module.exports = router;
