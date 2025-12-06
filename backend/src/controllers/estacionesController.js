const pool = require('../config/database');

/**
 * Obtener todas las estaciones activas
 * GET /api/estaciones
 */
exports.getAllEstaciones = async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, name, full_name as fullName, km, side,
              is_terminal as isTerminal, icon, activo, orden
       FROM ruta_estaciones
       WHERE activo = TRUE
       ORDER BY km ASC`
    );

    // Convertir valores booleanos
    const estaciones = rows.map(row => ({
      ...row,
      isTerminal: row.isTerminal === 1 || row.isTerminal === true,
      activo: row.activo === 1 || row.activo === true
    }));

    res.json(estaciones);
  } catch (error) {
    console.error('Error en getAllEstaciones:', error);
    res.status(500).json({ error: 'Error al obtener estaciones' });
  }
};

/**
 * Obtener estación por ID
 * GET /api/estaciones/:id
 */
exports.getEstacionById = async (req, res) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query(
      `SELECT id, name, full_name as fullName, km, side,
              is_terminal as isTerminal, icon, activo, orden
       FROM ruta_estaciones
       WHERE id = ?`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Estación no encontrada' });
    }

    const estacion = {
      ...rows[0],
      isTerminal: rows[0].isTerminal === 1 || rows[0].isTerminal === true,
      activo: rows[0].activo === 1 || rows[0].activo === true
    };

    res.json(estacion);
  } catch (error) {
    console.error('Error en getEstacionById:', error);
    res.status(500).json({ error: 'Error al obtener estación' });
  }
};

/**
 * Crear una nueva estación
 * POST /api/estaciones
 */
exports.createEstacion = async (req, res) => {
  try {
    const { id, name, fullName, km, side = 'center', isTerminal = false, icon, orden = 0 } = req.body;

    if (!id || !name || !fullName || km === undefined) {
      return res.status(400).json({ error: 'Faltan parámetros requeridos' });
    }

    await pool.query(
      `INSERT INTO ruta_estaciones
       (id, name, full_name, km, side, is_terminal, icon, orden)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, name, fullName, km, side, isTerminal, icon, orden]
    );

    res.status(201).json({
      id,
      message: 'Estación creada exitosamente'
    });
  } catch (error) {
    console.error('Error en createEstacion:', error);

    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'La estación ya existe con ese ID' });
    }

    res.status(500).json({ error: 'Error al crear estación' });
  }
};

/**
 * Actualizar estación
 * PUT /api/estaciones/:id
 */
exports.updateEstacion = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, fullName, km, side, isTerminal, icon, activo, orden } = req.body;

    const updates = [];
    const values = [];

    if (name !== undefined) {
      updates.push('name = ?');
      values.push(name);
    }
    if (fullName !== undefined) {
      updates.push('full_name = ?');
      values.push(fullName);
    }
    if (km !== undefined) {
      updates.push('km = ?');
      values.push(km);
    }
    if (side !== undefined) {
      updates.push('side = ?');
      values.push(side);
    }
    if (isTerminal !== undefined) {
      updates.push('is_terminal = ?');
      values.push(isTerminal);
    }
    if (icon !== undefined) {
      updates.push('icon = ?');
      values.push(icon);
    }
    if (activo !== undefined) {
      updates.push('activo = ?');
      values.push(activo);
    }
    if (orden !== undefined) {
      updates.push('orden = ?');
      values.push(orden);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No hay campos para actualizar' });
    }

    values.push(id);

    await pool.query(
      `UPDATE ruta_estaciones SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    res.json({ message: 'Estación actualizada exitosamente' });
  } catch (error) {
    console.error('Error en updateEstacion:', error);
    res.status(500).json({ error: 'Error al actualizar estación' });
  }
};

/**
 * Eliminar estación (soft delete)
 * DELETE /api/estaciones/:id
 */
exports.deleteEstacion = async (req, res) => {
  try {
    const { id } = req.params;

    await pool.query(
      'UPDATE ruta_estaciones SET activo = FALSE WHERE id = ?',
      [id]
    );

    res.json({ message: 'Estación eliminada exitosamente' });
  } catch (error) {
    console.error('Error en deleteEstacion:', error);
    res.status(500).json({ error: 'Error al eliminar estación' });
  }
};
