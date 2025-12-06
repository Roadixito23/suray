/**
 * Script de migración de datos desde Firebase/Firestore a MySQL
 *
 * Uso:
 * 1. Descargar el archivo de credenciales de Firebase Admin SDK
 * 2. Colocar el archivo como 'firebase-service-account.json' en la carpeta backend/
 * 3. Configurar las variables de entorno en .env
 * 4. Ejecutar: npm run migrate
 */

const admin = require('firebase-admin');
const pool = require('../config/database');
require('dotenv').config();

// Inicializar Firebase Admin
let serviceAccount;
try {
  serviceAccount = require('../../firebase-service-account.json');
} catch (error) {
  console.error('❌ Error: No se encontró el archivo firebase-service-account.json');
  console.error('Descárgalo desde la consola de Firebase y colócalo en la carpeta backend/');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID
});

const firestore = admin.firestore();

// Función principal de migración
async function migrate() {
  console.log('\n╔═══════════════════════════════════════════════════════╗');
  console.log('║   🔄 MIGRACIÓN DE FIREBASE A MYSQL                   ║');
  console.log('╚═══════════════════════════════════════════════════════╝\n');

  try {
    // Migrar horarios
    console.log('📅 Migrando horarios...');
    await migrateHorarios();
    console.log('✅ Horarios migrados exitosamente\n');

    // Migrar feriados
    console.log('🎉 Migrando feriados...');
    await migrateFeriados();
    console.log('✅ Feriados migrados exitosamente\n');

    // Migrar estaciones
    console.log('🚏 Migrando estaciones de ruta...');
    await migrateEstaciones();
    console.log('✅ Estaciones migradas exitosamente\n');

    console.log('╔═══════════════════════════════════════════════════════╗');
    console.log('║   ✅ MIGRACIÓN COMPLETADA EXITOSAMENTE               ║');
    console.log('╚═══════════════════════════════════════════════════════╝\n');

  } catch (error) {
    console.error('\n❌ Error durante la migración:', error);
    process.exit(1);
  } finally {
    await pool.end();
    process.exit(0);
  }
}

/**
 * Migrar horarios desde Firebase a MySQL
 * Estructura Firebase: horarios/{region}/{tipo_dia}/{doc_id} -> { time: "HH:MM" }
 */
async function migrateHorarios() {
  const regions = ['aysen', 'coyhaique'];
  const tiposDia = ['lunesViernes', 'sabados', 'domingosFeriados'];

  let totalMigrated = 0;

  for (const region of regions) {
    for (const tipoDia of tiposDia) {
      const snapshot = await firestore
        .collection('horarios')
        .doc(region)
        .collection(tipoDia)
        .get();

      console.log(`   → ${region}/${tipoDia}: ${snapshot.size} horarios`);

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const time = data.time;

        if (!time) {
          console.log(`   ⚠️  Advertencia: Documento sin campo 'time' en ${region}/${tipoDia}/${doc.id}`);
          continue;
        }

        try {
          // Insertar en MySQL (ignorar duplicados)
          await pool.query(
            `INSERT INTO horarios (region, tipo_dia, hora, activo)
             VALUES (?, ?, ?, TRUE)
             ON DUPLICATE KEY UPDATE hora = hora`,
            [region, tipoDia, time]
          );
          totalMigrated++;
        } catch (error) {
          console.error(`   ❌ Error insertando horario ${time}:`, error.message);
        }
      }
    }
  }

  console.log(`   📊 Total de horarios migrados: ${totalMigrated}`);
}

/**
 * Migrar feriados desde Firebase a MySQL
 * Estructura Firebase: feriados/{año} -> { "MM-DD": { nombre: "...", activo: true } }
 */
async function migrateFeriados() {
  const feriadosSnapshot = await firestore.collection('feriados').get();

  let totalMigrated = 0;

  for (const doc of feriadosSnapshot.docs) {
    const anio = parseInt(doc.id);
    const feriadosData = doc.data();

    console.log(`   → Año ${anio}: ${Object.keys(feriadosData).length} feriados`);

    for (const [fecha, info] of Object.entries(feriadosData)) {
      // Parsear fecha "MM-DD"
      const [mes, dia] = fecha.split('-').map(Number);

      if (!info.nombre) {
        console.log(`   ⚠️  Advertencia: Feriado sin nombre en ${anio}/${fecha}`);
        continue;
      }

      try {
        // Insertar en MySQL
        await pool.query(
          `INSERT INTO feriados (anio, mes, dia, nombre, activo)
           VALUES (?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE nombre = ?, activo = ?`,
          [anio, mes, dia, info.nombre, info.activo !== false, info.nombre, info.activo !== false]
        );
        totalMigrated++;
      } catch (error) {
        console.error(`   ❌ Error insertando feriado ${fecha}/${anio}:`, error.message);
      }
    }
  }

  console.log(`   📊 Total de feriados migrados: ${totalMigrated}`);
}

/**
 * Migrar estaciones de ruta desde Firebase a MySQL
 * Estructura Firebase: ruta_estaciones/{doc_id} -> { id, name, fullName, km, side, isTerminal, activo }
 */
async function migrateEstaciones() {
  const snapshot = await firestore.collection('ruta_estaciones').get();

  let totalMigrated = 0;

  console.log(`   → Total de estaciones en Firebase: ${snapshot.size}`);

  for (const doc of snapshot.docs) {
    const data = doc.data();

    // Validar campos requeridos
    if (!data.id || !data.name || !data.fullName || data.km === undefined) {
      console.log(`   ⚠️  Advertencia: Estación con campos incompletos: ${doc.id}`);
      continue;
    }

    try {
      // Insertar en MySQL
      await pool.query(
        `INSERT INTO ruta_estaciones
         (id, name, full_name, km, side, is_terminal, icon, activo, orden)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           name = ?,
           full_name = ?,
           km = ?,
           side = ?,
           is_terminal = ?,
           icon = ?,
           activo = ?,
           orden = ?`,
        [
          data.id,
          data.name,
          data.fullName,
          data.km,
          data.side || 'center',
          data.isTerminal || false,
          data.icon || null,
          data.activo !== false,
          data.orden || 0,
          // Valores para UPDATE
          data.name,
          data.fullName,
          data.km,
          data.side || 'center',
          data.isTerminal || false,
          data.icon || null,
          data.activo !== false,
          data.orden || 0
        ]
      );
      totalMigrated++;
    } catch (error) {
      console.error(`   ❌ Error insertando estación ${data.id}:`, error.message);
    }
  }

  console.log(`   📊 Total de estaciones migradas: ${totalMigrated}`);
}

// Ejecutar migración
migrate();
