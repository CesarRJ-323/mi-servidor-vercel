// Seed con Firebase Admin SDK — usa gRPC hacia el emulador Firestore
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8383';

const app = admin.initializeApp({
  projectId: 'deliverymovile-c25ff',
});

const db = getFirestore(app);
// Explícitamente apuntar al emulador
db.settings({ host: '127.0.0.1:8383', ssl: false });

async function seed() {
  const ahora = new Date().toISOString();
  console.log('🌱 Seedeando con Firebase Admin SDK...\n');

  // 1. Promos
  const promos = [
    { id: 'promo_70_bebidas', data: {
      nombre: '70% OFF Bebidas', descripcion: 'Válido solo para hoy',
      tipo: 'porcentaje', valor: 70, aplicar_a: 'categoria:bebidas',
      duracion: 'Hoy', activa: true, fecha_creacion: ahora,
    }},
    { id: 'promo_2x1_cereales', data: {
      nombre: '2x1 Cereales', descripcion: 'Segundo a mitad de precio',
      tipo: '2x1', valor: 1, aplicar_a: 'categoria:cereales',
      duracion: 'Hoy', activa: true, fecha_creacion: ahora,
    }},
  ];
  for (const p of promos) {
    await db.collection('promos').doc(p.id).set(p.data);
    console.log('  ✅ promos/' + p.id);
  }

  // 2. Descuentos
  const descuentos = [
    { id: 'bebidas', data: { categoria: 'bebidas', porcentaje: 10, activo: true, tipo: 'categoria' }},
    { id: 'cereales', data: { categoria: 'cereales', porcentaje: 10, activo: true, tipo: 'categoria' }},
  ];
  for (const d of descuentos) {
    await db.collection('descuentos').doc(d.id).set(d.data);
    console.log('  ✅ descuentos/' + d.id);
  }

  // 3. Sorteo activo
  await db.collection('sorteos').doc('sorteo_seed_0').set({
    titulo: 'Ganá una taza personalizada',
    descripcion: 'Participá con tu ticket por una taza exclusiva.',
    activo: true, terminado: false,
    fecha_sorteo: new Date(Date.now() + 5 * 86400000).toISOString(),
    participantes: [], nombres_participantes: [],
    creado_en: ahora,
  });
  console.log('  ✅ sorteos/sorteo_seed_0');

  // 4. Usuario admin
  await db.collection('usuarios').doc('uid_admin_test').set({
    nombre: 'César Rapidiya',
    email: 'alegandraaraoz@gmail.com',
    rol: 'admin', tokens_balance: 999, tickets_balance: 50,
    fecha_creacion: ahora,
  });
  console.log('  ✅ usuarios/uid_admin_test');

  // 5. Productos
  const prods = [
    { nombre: 'Café Express', categoria: 'bebidas', precio_base: 250, disponible: true },
    { nombre: 'Café Latte', categoria: 'bebidas', precio_base: 320, disponible: true },
    { nombre: 'Té Helado', categoria: 'bebidas', precio_base: 200, disponible: true },
    { nombre: 'Cereal Granola', categoria: 'cereales', precio_base: 450, disponible: true },
    { nombre: 'Brownie', categoria: 'postres', precio_base: 280, disponible: true },
  ];
  for (const p of prods) {
    const id = p.nombre.toLowerCase().replace(/\s/g, '_');
    await db.collection('productos').doc(id).set(p);
    console.log('  ✅ productos/' + id);
  }

  console.log('\n🎯 Seed completado!');
  process.exit(0);
}

seed().catch(e => {
  console.error('❌ Seed error:', e.message);
  process.exit(1);
});
