// Seed script: inserta datos de prueba en el emulador Firestore
const baseUrl = 'http://127.0.0.1:8383/firestore/v1/projects/deliverymovile-c25ff/databases/(default)/documents';

function toFields(obj) {
  const fields = {};
  for (const [key, value] of Object.entries(obj)) {
    if (value === null || value === undefined) {
      fields[key] = { nullValue: null };
    } else if (typeof value === 'string') {
      fields[key] = { stringValue: value };
    } else if (typeof value === 'number') {
      fields[key] = Number.isInteger(value) ? { integerValue: value } : { doubleValue: value };
    } else if (typeof value === 'boolean') {
      fields[key] = { booleanValue: value };
    } else if (Array.isArray(value)) {
      const vals = value.map(v => {
        if (v === null) return { nullValue: null };
        if (typeof v === 'string') return { stringValue: v };
        if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: v } : { doubleValue: v };
        if (typeof v === 'boolean') return { booleanValue: v };
        return { stringValue: String(v) };
      });
      fields[key] = { arrayValue: { values: vals } };
    } else {
      fields[key] = { stringValue: String(value) };
    }
  }
  return fields;
}

// Firestore REST: POST /{collection}?documentId={id} crea el documento
async function api(collection, docId, body) {
  const res = await fetch(baseUrl + '/' + collection + '?documentId=' + docId, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body ? { fields: toFields(body) } : {}),
  });
  const txt = await res.text();
  const status = res.ok ? '✅' : '❌';
  console.log(status, collection + '/' + docId, res.status);
  if (!res.ok) console.log('  Error:', txt.substring(0, 250));
}

async function seed() {
  const ahora = new Date().toISOString();

  // Promos
  await api('promos', 'promo_70_bebidas', {
    nombre: '70% OFF Bebidas',
    descripcion: 'Válido solo para hoy',
    tipo: 'porcentaje', valor: 70,
    aplicar_a: 'categoria:bebidas',
    duracion: 'Hoy', activa: true,
    fecha_creacion: ahora,
  });
  await api('promos', 'promo_2x1_cereales', {
    nombre: '2x1 Cereales',
    descripcion: 'Segundo a mitad de precio',
    tipo: '2x1', valor: 1,
    aplicar_a: 'categoria:cereales',
    duracion: 'Hoy', activa: true,
    fecha_creacion: ahora,
  });

  // Descuentos
  await api('descuentos', 'bebidas', { categoria: 'bebidas', porcentaje: 10, activo: true, tipo: 'categoria' });
  await api('descuentos', 'cereales', { categoria: 'cereales', porcentaje: 10, activo: true, tipo: 'categoria' });

  // Sorteo
  await api('sorteos', 'sorteo_seed_0', {
    titulo: 'Ganá una taza personalizada',
    descripcion: 'Participá con tu ticket por una taza exclusiva.',
    activo: true, terminado: false,
    fecha_sorteo: new Date(Date.now() + 5 * 86400000).toISOString(),
    participantes: [], nombres_participantes: [],
    creado_en: ahora,
  });

  // Usuario admin
  await api('usuarios', 'uid_admin_test', {
    nombre: 'César Rapidiya',
    email: 'alegandraaraoz@gmail.com',
    rol: 'admin', tokens_balance: 999, tickets_balance: 50,
    fecha_creacion: ahora,
  });

  // Productos
  const prods = [
    { nombre: 'Café Express', categoria: 'bebidas', precio_base: 250, disponible: true },
    { nombre: 'Café Latte', categoria: 'bebidas', precio_base: 320, disponible: true },
    { nombre: 'Té Helado', categoria: 'bebidas', precio_base: 200, disponible: true },
    { nombre: 'Cereal Granola', categoria: 'cereales', precio_base: 450, disponible: true },
    { nombre: 'Brownie', categoria: 'postres', precio_base: 280, disponible: true },
  ];
  for (const p of prods) {
    const id = p.nombre.toLowerCase().replace(/\s/g, '_');
    await api('productos', id, p);
  }

  console.log('\n🎯 Seed finalizado - datos cargados en el emulador');
}

seed().catch(e => console.error('Error:', e.message));
