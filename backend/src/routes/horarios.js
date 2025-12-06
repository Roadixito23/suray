const express = require('express');
const router = express.Router();
const horariosController = require('../controllers/horariosController');

// Obtener horarios por región y tipo de día
router.get('/:region/:tipo_dia', horariosController.getHorariosByRegionAndTipo);

// Obtener todos los horarios de una región
router.get('/:region', horariosController.getAllHorariosByRegion);

// Crear nuevo horario
router.post('/', horariosController.createHorario);

// Eliminar horario
router.delete('/:id', horariosController.deleteHorario);

module.exports = router;
