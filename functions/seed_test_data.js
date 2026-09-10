/**
 * Seed Firestore + Auth emuladores con datos de prueba
 * Ejecutar desde functions/: node seed_test_data.js
 */
const admin = require('firebase-admin');

// Force emulator connection
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8787';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9494';

admin.initializeApp({ projectId: 'deliverymovile-c25ff' });

const db = admin.firestore();
const auth = admin.auth();

async function seedEverything() {
  console.log('🌱 Sembrando datos de prueba...\n');

  // 1. Usuario en Auth
  try {
    await auth.createUser({
      uid: 'test-user-001',
      email: 'alegandraaraoz@gmail.com',
      password: 'rapidiya123',
      displayName: 'César Test',
      emailVerified: true,
    });
    console.log('✅ Usuario Auth: alegandraaraoz@gmail.com');
  } catch (e) {
    if (e.code === 'auth/uid-already-exists') {
      console.log('ℹ️  Usuario existente: test-user-001');
    } else {
      console.log('❌ Auth error:', e.message);
    }
  }

  // 2. Usuario en Firestore
  await db.collection('usuarios').doc('test-user-001').set({
    uid: 'test-user-001',
    email: 'alegandraaraoz@gmail.com',
    nombre: 'César Test',
    role: 'admin',
    fecha_registro: admin.firestore.FieldValue.serverTimestamp(),
    balance: 0,
    tickets: 0,
  });
  console.log('✅ Usuario Firestore: test-user-001');

  // 3. Categorías
  await db.collection('categorias').doc('cat-bebidas').set({
    id: 'cat-bebidas', nombre: 'Bebidas', icono: '🥤', orden: 1, activo: true
  });
  await db.collection('categorias').doc('cat-desayunos').set({
    id: 'cat-desayunos', nombre: 'Desayunos', icono: '🍳', orden: 2, activo: true
  });
  console.log('✅ Categorías');

  // 4. Productos
  await db.collection('productos').doc('prod-avena').set({
    id: 'prod-avena',
    nombre: 'Avena integral',
    descripcion: 'Avena integral Premium',
    precio: 144,
    categoria_id: 'cat-desayunos',
    imagen_url: 'https://via.placeholder.com/150',
    activo: true,
    stock: 100,
    destacado: true,
    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection('productos').doc('prod-cafe').set({
    id: 'prod-cafe',
    nombre: 'Café molido',
    descripcion: 'Café molido oscuro',
    precio: 850,
    categoria_id: 'cat-bebidas',
    imagen_url: 'https://via.placeholder.com/150',
    activo: true,
    stock: 50,
    destacado: false,
    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('✅ Productos: Avena ($144), Café ($850)');

  // 5. Promo
  await db.collection('promociones').doc('promo-test').set({
    id: 'promo-test',
    titulo: 'Descuento Test 10%',
    descripcion: '10% de descuento en todo',
    codigo: 'TEST10',
    tipo: 'porcentaje',
    valor: 10,
    aplicar_a: 'categoria:bebidas',
    activo: true,
    fecha_inicio: admin.firestore.Timestamp.now(),
    fecha_fin: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
  });
  console.log('✅ Promo: TEST10');

  // 6. Config
  await db.collection('config').doc('general').set({
    moneda: 'ARS',
    envio_gratis_desde: 1000,
    tasa_envio: 0,
  });
  console.log('✅ Config');

  console.log('\n🎉 ¡SEED COMPLETO!');
  console.log('Login: alegandraaraoz@gmail.com / rapidiya123');
}

seedEverything().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});