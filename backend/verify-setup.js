/**
 * Script de verificación de configuración
 * Verifica que todo esté correctamente configurado antes de ejecutar el servidor
 */

const fs = require('fs');
const path = require('path');

console.log('\n╔═══════════════════════════════════════════════════════╗');
console.log('║   🔍 VERIFICACIÓN DE CONFIGURACIÓN                   ║');
console.log('╚═══════════════════════════════════════════════════════╝\n');

let hasErrors = false;

// 1. Verificar que existe el archivo .env
console.log('1. Verificando archivo .env...');
if (!fs.existsSync('.env')) {
  console.log('   ❌ No se encontró el archivo .env');
  console.log('   💡 Ejecuta: cp .env.example .env');
  console.log('   📝 Luego edita el archivo .env con tus credenciales\n');
  hasErrors = true;
} else {
  console.log('   ✅ Archivo .env encontrado\n');

  // Verificar variables de entorno
  require('dotenv').config();

  const requiredVars = [
    'DB_HOST',
    'DB_USER',
    'DB_PASSWORD',
    'DB_NAME'
  ];

  console.log('2. Verificando variables de entorno...');
  let missingVars = [];

  requiredVars.forEach(varName => {
    if (!process.env[varName]) {
      missingVars.push(varName);
    }
  });

  if (missingVars.length > 0) {
    console.log('   ❌ Faltan las siguientes variables:');
    missingVars.forEach(varName => {
      console.log(`      - ${varName}`);
    });
    console.log('   📝 Edita el archivo .env y configura estas variables\n');
    hasErrors = true;
  } else {
    console.log('   ✅ Todas las variables de entorno están configuradas\n');

    // 3. Intentar conectar a la base de datos
    console.log('3. Probando conexión a MySQL...');

    const mysql = require('mysql2/promise');

    (async () => {
      try {
        const connection = await mysql.createConnection({
          host: process.env.DB_HOST,
          user: process.env.DB_USER,
          password: process.env.DB_PASSWORD,
          database: process.env.DB_NAME,
          port: process.env.DB_PORT || 3306,
        });

        console.log('   ✅ Conexión a MySQL exitosa\n');

        // 4. Verificar que existan las tablas
        console.log('4. Verificando tablas en la base de datos...');

        const [tables] = await connection.query("SHOW TABLES");
        const tableNames = tables.map(row => Object.values(row)[0]);

        const requiredTables = ['horarios', 'feriados', 'ruta_estaciones'];
        const missingTables = requiredTables.filter(t => !tableNames.includes(t));

        if (missingTables.length > 0) {
          console.log('   ⚠️  Faltan las siguientes tablas:');
          missingTables.forEach(tableName => {
            console.log(`      - ${tableName}`);
          });
          console.log('   💡 Ejecuta el script SQL: scriptsql/suray_web_serve.sql\n');
        } else {
          console.log('   ✅ Todas las tablas existen\n');

          // 5. Verificar datos en las tablas
          console.log('5. Verificando datos en las tablas...');

          for (const table of requiredTables) {
            const [rows] = await connection.query(`SELECT COUNT(*) as count FROM ${table}`);
            const count = rows[0].count;

            if (count === 0) {
              console.log(`   ⚠️  La tabla ${table} está vacía`);
            } else {
              console.log(`   ✅ ${table}: ${count} registros`);
            }
          }

          console.log('');
        }

        await connection.end();

        // 6. Verificar node_modules
        console.log('6. Verificando dependencias de Node.js...');
        if (!fs.existsSync('node_modules')) {
          console.log('   ❌ No se encontró la carpeta node_modules');
          console.log('   💡 Ejecuta: npm install\n');
          hasErrors = true;
        } else {
          console.log('   ✅ Dependencias instaladas\n');
        }

        // Resumen final
        console.log('╔═══════════════════════════════════════════════════════╗');
        if (!hasErrors) {
          console.log('║   ✅ TODO ESTÁ LISTO                                 ║');
          console.log('║   Ejecuta: npm run dev                               ║');
        } else {
          console.log('║   ⚠️  HAY ERRORES QUE CORREGIR                      ║');
          console.log('║   Revisa los mensajes anteriores                     ║');
        }
        console.log('╚═══════════════════════════════════════════════════════╝\n');

      } catch (error) {
        console.log('   ❌ Error al conectar a MySQL:');
        console.log(`   ${error.message}\n`);
        console.log('   💡 Verifica que:');
        console.log('      - MySQL esté corriendo');
        console.log('      - Las credenciales en .env sean correctas');
        console.log('      - El usuario tenga permisos sobre la base de datos\n');

        console.log('╔═══════════════════════════════════════════════════════╗');
        console.log('║   ❌ ERROR DE CONEXIÓN                               ║');
        console.log('║   Revisa la configuración de MySQL                    ║');
        console.log('╚═══════════════════════════════════════════════════════╝\n');

        process.exit(1);
      }
    })();
  }
}

if (hasErrors) {
  process.exit(1);
}
