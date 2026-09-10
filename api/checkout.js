import admin from 'firebase-admin';
import { MercadoPagoConfig, Preference } from 'mercadopago';

// Inicializar Firebase
if (!admin.apps.length) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  } catch (error) {
    console.error('Error inicializando Firebase Admin', error);
  }
}

const db = admin.apps.length ? admin.firestore() : null;

export default async function handler(req, res) {
  // Configurar CORS
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  if (!db) {
    return res.status(500).json({ error: 'Firebase Admin no configurado' });
  }

  const { items, externalReference, userId, userEmail } = req.body;

  if (!items || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'Se requiere al menos un item' });
  }
  if (!externalReference) {
    return res.status(400).json({ error: 'Se requiere externalReference' });
  }

  try {
    let realTotal = 0;
    const mpItems = [];
    
    for (const item of items) {
      if (!item.id || !item.cantidad) continue;
      
      const productDoc = await db.collection('productos').doc(item.id).get();
      if (!productDoc.exists) {
        throw new Error(`Producto no encontrado: ${item.id}`);
      }
      
      const productData = productDoc.data();
      const price = productData.precio_base || 0;
      realTotal += price * item.cantidad;
      
      mpItems.push({
        id: item.id,
        title: productData.nombre || 'Producto',
        quantity: item.cantidad,
        unit_price: Number(price),
        currency_id: 'ARS',
      });
    }

    if (mpItems.length === 0) {
      throw new Error('No hay productos válidos para cobrar');
    }

    // Configurar Mercado Pago
    const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN, options: { timeout: 5000 } });
    const preference = new Preference(client);

    const response = await preference.create({
      body: {
        items: mpItems,
        payer: {
          email: userEmail,
        },
        back_urls: {
          success: 'rapidiya://pago/exito',
          failure: 'rapidiya://pago/fallo',
          pending: 'rapidiya://pago/pendiente',
        },
        auto_return: 'approved',
        external_reference: externalReference,
        statement_descriptor: 'Rapidiya',
      }
    });

    return res.status(200).json({
      ok: true,
      preferenceId: response.id,
      initPoint: response.init_point,
      sandboxInitPoint: response.sandbox_init_point,
    });
  } catch (error) {
    console.error('Error creando preferencia MP', error);
    return res.status(500).json({ error: error.message || 'Error interno' });
  }
}
