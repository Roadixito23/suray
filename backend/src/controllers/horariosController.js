const pool = require('../config/database');

/**
 * Obtener horarios por región y tipo de día
 * GET /api/horarios/:region/:tipo_dia
 */
exports.getHorariosByRegionAndTipo = async (req, res) => {
  try {
    const { region, tipo_dia } = req.params;

    // Validar parámetros
    const validRegions = ['aysen', 'coyhaique'];
    const validTipos = ['lunesViernes', 'sabados', 'domingosFeriados'];

    if (!validRegions.includes(region)) {
      return res.status(400).json({ error: 'Región inválida' });
    }
    if (!validTipos.includes(tipo_dia)) {
      return res.status(400).json({ error: 'Tipo de día inválido' });
    }

    const [rows] = await pool.query(
      `SELECT TIME_FORMAT(hora, '%H:%i') as time
       FROM horarios
       WHERE region = ? AND tipo_dia = ? AND activo = TRUE
       ORDER BY hora ASC`,
      [region, tipo_dia]
    );

    // Devolver en formato compatible con Firebase (array de objetos con field 'time')
    const times = rows.map(row => ({ time: row.time }));

    res.json(times);
  } catch (error) {
    console.error('Error en getHorariosByRegionAndTipo:', error);
    res.status(500).json({ error: 'Error al obtener horarios' });
  }
};

/**
 * Obtener todos los horarios de una región
 * GET /api/horarios/:region
 */
exports.getAllHorariosByRegion = async (req, res) => {
  try {
    const { region } = req.params;

    const validRegions = ['aysen', 'coyhaique'];
    if (!validRegions.includes(region)) {
      return res.status(400).json({ error: 'Región inválida' });
    }

    const [rows] = await pool.query(
      `SELECT tipo_dia, TIME_FORMAT(hora, '%H:%i') as time
       FROM horarios
       WHERE region = ? AND activo = TRUE
       ORDER BY tipo_dia, hora ASC`,
      [region]
    );

    // Agrupar por tipo de día
    const grouped = {
      lunesViernes: [],
      sabados: [],
      domingosFeriados: []
    };

    rows.forEach(row => {
      grouped[row.tipo_dia].push({ time: row.time });
    });

    res.json(grouped);
  } catch (error) {
    console.error('Error en getAllHorariosByRegion:', error);
    res.status(500).json({ error: 'Error al obtener horarios' });
  }
};

/**
 * Crear un nuevo horario
 * POST /api/horarios
 */
exports.createHorario = async (req, res) => {
  try {
    const { region, tipo_dia, hora } = req.body;

    // Validar parámetros
    if (!region || !tipo_dia || !hora) {
      return res.status(400).json({ error: 'Faltan parámetros requeridos' });
    }

    const [result] = await pool.query(
      'INSERT INTO horarios (region, tipo_dia, hora) VALUES (?, ?, ?)',
      [region, tipo_dia, hora]
    );

    res.status(201).json({
      id: result.insertId,
      message: 'Horario creado exitosamente'
    });
  } catch (error) {
    console.error('Error en createHorario:', error);
    res.status(500).json({ error: 'Error al crear horario' });
  }
};

/**
 * Eliminar horario (soft delete)
 * DELETE /api/horarios/:id
 */
exports.deleteHorario = async (req, res) => {
  try {
    const { id } = req.params;

    await pool.query(
      'UPDATE horarios SET activo = FALSE WHERE id = ?',
      [id]
    );

    res.json({ message: 'Horario eliminado exitosamente' });
  } catch (error) {
    console.error('Error en deleteHorario:', error);
    res.status(500).json({ error: 'Error al eliminar horario' });
  }
};
