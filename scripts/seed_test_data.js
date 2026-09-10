/**
 * Seed Firestore + Auth emuladores con datos de prueba
 * Incluye: usuario, productos, promos, categorías
 */
const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8787';

const app = admin.initializeApp({
  projectId: 'deliverymovile-c25ff'
});

const db = admin.firestore(app);
const auth = admin.auth(app);

async function seedEverything() {
  console.log('🌱 Sembrando datos de prueba...\n');

  // 1. Crear usuario en Auth (email: alegandraaraoz@gmail.com, password: rapidiya123)
  try {
    await auth.createUser({
      uid: 'test-user-001',
      email: 'alegandraaraoz@gmail.com',
      password: 'rapidiya123',
      displayName: 'César Test',
      emailVerified: true,
    });
    console.log('✅ Usuario creado: alegandraaraoz@gmail.com (uid: test-user-001)');
  } catch (e) {
    if (e.code === 'auth/uid-already-exists') {
      console.log('ℹ️  Usuario ya existe: test-user-001');
    } else {
      console.log('❌ Error creando usuario:', e.message);
    }
  }

  // 2. Crear usuario en Firestore (mismatches collection)
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
    id: 'cat-bebidas',
    nombre: 'Bebidas',
    icono: '🥤',
    orden: 1,
    activo: true,
  });
  await db.collection('categorias').doc('cat-desayunos').set({
    id: 'cat-desayunos',
    nombre: 'Desayunos',
    icono: '🍳',
    orden: 2,
    activo: true,
  });
  console.log('✅ Categorías: cat-bebidas, cat-desayunos');

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
  console.log('✅ Productos: Avena integral ($144), Café molido ($850)');

  // 5. Promos
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
  console.log('✅ Promo: TEST10 (10% en categoría:bebidas)');

  // 6. Config básica
  await db.collection('config').doc('general').set({
    moneda: 'ARS',
    envio_gratis_desde: 1000,
    tasa_envio: 0,
  });
  console.log('✅ Config general');

  console.log('\n🎉 ¡Seedeo completo!');
  console.log('\n📱 Datos para testing:');
  console.log('   Email: alegandraaraoz@gmail.com');
  console.log('   Password: rapidiya123');
  console.log('   Producto: Avena integral ($144)');
}

seedEverything().catch(console.error);
