const pool = require('../config/database');

/**
 * Obtener feriados por año
 * GET /api/feriados/:anio
 */
exports.getFeriadosByAnio = async (req, res) => {
  try {
    const { anio } = req.params;

    const [rows] = await pool.query(
      `SELECT mes, dia, nombre, activo
       FROM feriados
       WHERE anio = ?
       ORDER BY mes, dia`,
      [anio]
    );

    // Convertir a formato Firebase: { "MM-DD": { nombre, activo } }
    const feriados = {};
    rows.forEach(row => {
      const key = `${String(row.mes).padStart(2, '0')}-${String(row.dia).padStart(2, '0')}`;
      feriados[key] = {
        nombre: row.nombre,
        activo: row.activo === 1 || row.activo === true
      };
    });

    res.json(feriados);
  } catch (error) {
    console.error('Error en getFeriadosByAnio:', error);
    res.status(500).json({ error: 'Error al obtener feriados' });
  }
};

/**
 * Crear un nuevo feriado
 * POST /api/feriados
 */
exports.createFeriado = async (req, res) => {
  try {
    const { anio, mes, dia, nombre, activo = true } = req.body;

    if (!anio || !mes || !dia || !nombre) {
      return res.status(400).json({ error: 'Faltan parámetros requeridos' });
    }

    const [result] = await pool.query(
      'INSERT INTO feriados (anio, mes, dia, nombre, activo) VALUES (?, ?, ?, ?, ?)',
      [anio, mes, dia, nombre, activo]
    );

    res.status(201).json({
      id: result.insertId,
      message: 'Feriado creado exitosamente'
    });
  } catch (error) {
    console.error('Error en createFeriado:', error);

    // Si es error de duplicado
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'El feriado ya existe para esa fecha' });
    }

    res.status(500).json({ error: 'Error al crear feriado' });
  }
};

/**
 * Actualizar un feriado
 * PUT /api/feriados/:id
 */
exports.updateFeriado = async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre, activo } = req.body;

    const updates = [];
    const values = [];

    if (nombre !== undefined) {
      updates.push('nombre = ?');
      values.push(nombre);
    }
    if (activo !== undefined) {
      updates.push('activo = ?');
      values.push(activo);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No hay campos para actualizar' });
    }

    values.push(id);

    await pool.query(
      `UPDATE feriados SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ message: 'Feriado actualizado exitosamente' });
  } catch (error) {
    console.error('Error en updateFeriado:', error);
    res.status(500).json({ error: 'Error al actualizar feriado' });
  }
};

/**
 * Eliminar feriado (soft delete)
 * DELETE /api/feriados/:id
 */
exports.deleteFeriado = async (req, res) => {
  try {
    const { id } = req.params;

    await pool.query(
      'UPDATE feriados SET activo = FALSE WHERE id = ?',
      [id]
    );

    res.json({ message: 'Feriado eliminado exitosamente' });
  } catch (error) {
    console.error('Error en deleteFeriado:', error);
    res.status(500).json({ error: 'Error al eliminar feriado' });
  }
};
