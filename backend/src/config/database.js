const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '-03:00', // Zona horaria de Chile
});

// Probar conexión
pool.getConnection()
  .then(connection => {
    console.log('✅ Conexión exitosa a la base de datos MySQL');
    connection.release();
  })
  .catch(err => {
    console.error('❌ Error al conectar a la base de datos:', err.message);
  });

module.exports = pool;
