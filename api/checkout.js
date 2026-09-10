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
    let totalTokens = 0;
    const mpItems = [];
    
    for (const item of items) {
      if (!item.id || !item.cantidad) continue;
      
      const productDoc = await db.collection('productos').doc(item.id).get();
      if (!productDoc.exists) {
        throw new Error(`Producto no encontrado: ${item.id}`);
      }
      
      const productData = productDoc.data();
      
      // El ítem en el carrito nos dice si el usuario ELIGIÓ pagar con tokens
      const userChoseTokens = item.requiereTokens === true || item.requiere_tokens === true;
      const permiteTokens = productData.permite_tokens === true || productData.requiere_tokens === true;
      
      if (userChoseTokens && !permiteTokens) {
        throw new Error(`El producto ${item.id} no permite ser comprado con tokens.`);
      }

      if (userChoseTokens) {
        const precioTokens = productData.precio_tokens || 0;
        totalTokens += precioTokens * item.cantidad;
      } else {
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
    }

    // Verificar saldo de tokens si hay productos que lo requieran
    if (totalTokens > 0) {
      const userDoc = await db.collection('usuarios').doc(userId).get();
      if (!userDoc.exists) {
        throw new Error('Usuario no encontrado');
      }
      const userData = userDoc.data();
      const userTokens = userData.tokens_balance || 0;

      if (userTokens < totalTokens) {
        return res.status(400).json({ error: `Tokens insuficientes. Necesitas ${totalTokens} 🪙 pero tienes ${userTokens} 🪙` });
      }

      // Dejar anotado cuántos tokens hay que descontarle cuando pague en Mercado Pago
      // Si el pedido es 100% tokens, lo descontaremos ahora mismo.
      await db.collection('pedidos').doc(externalReference).update({
        tokensAbonar: totalTokens
      });
    }

    if (mpItems.length === 0) {
      // Es un pedido 100% con tokens. Descontar tokens ahora y marcar como pagado.
      if (totalTokens > 0) {
        const admin = require('firebase-admin');
        await db.collection('usuarios').doc(userId).update({
          tokens_balance: admin.firestore.FieldValue.increment(-totalTokens)
        });
        await db.collection('pedidos').doc(externalReference).update({
          estado: 'pagado'
        });
        return res.status(200).json({ init_point: 'rapidiya://pago/exito' });
      } else {
        throw new Error('No hay productos válidos para cobrar');
      }
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
        notification_url: `https://${req.headers.host}/api/webhook`,
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
