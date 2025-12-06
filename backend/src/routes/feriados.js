const express = require('express');
const router = express.Router();
const feriadosController = require('../controllers/feriadosController');

// Obtener feriados por año
router.get('/:anio', feriadosController.getFeriadosByAnio);

// Crear nuevo feriado
router.post('/', feriadosController.createFeriado);

// Actualizar feriado
router.put('/:id', feriadosController.updateFeriado);

// Eliminar feriado
router.delete('/:id', feriadosController.deleteFeriado);

module.exports = router;
