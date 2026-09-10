import admin from 'firebase-admin';
import { MercadoPagoConfig, Payment } from 'mercadopago';

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

const mapMPStatusToPedidoStatus = (mpStatus) => {
  switch (mpStatus) {
    case 'approved': return 'pagado';
    case 'pending':
    case 'in_process': return 'pendiente';
    case 'rejected': return 'fallido';
    case 'cancelled':
    case 'null': return 'cancelado';
    default: return 'pendiente';
  }
};

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  // Responder rápido a MP (200 OK) para evitar reintentos.
  res.status(200).send('OK');

  if (!db) {
    console.error('Firebase Admin no configurado');
    return;
  }

  const { type, data } = req.body;
  const topic = req.query.topic || type;
  const paymentId = req.query['data.id'] || (data && data.id);

  if (topic === 'payment' && paymentId) {
    try {
      const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN });
      const paymentClient = new Payment(client);
      const paymentData = await paymentClient.get({ id: paymentId });

      const externalRef = paymentData.external_reference;
      if (!externalRef) return;

      const pedidoRef = db.collection('pedidos').doc(externalRef);
      const pedidoDoc = await pedidoRef.get();

      if (!pedidoDoc.exists) {
        console.log(`No se encontró pedido con id ${externalRef}`);
        return;
      }

      const pedidoData = pedidoDoc.data();
      const nuevoStatus = mapMPStatusToPedidoStatus(paymentData.status);

      const batch = db.batch();

      batch.update(pedidoRef, {
        'estado_pago': nuevoStatus,
        'mp_payment_id': paymentData.id.toString(),
        'mp_status': paymentData.status,
        'mp_status_detail': paymentData.status_detail,
        'fecha_actualizacion': admin.firestore.FieldValue.serverTimestamp(),
      });

      if (nuevoStatus === 'pagado' && pedidoData.estado_pago !== 'pagado') {
        let totalItems = 0;
        if (pedidoData.items && Array.isArray(pedidoData.items)) {
          totalItems = pedidoData.items.reduce((sum, item) => sum + (item.cantidad || 1), 0);
        }
        
        let tokensChange = totalItems;
        if (pedidoData.tokensAbonar) {
          tokensChange -= pedidoData.tokensAbonar;
        }
        
        if (tokensChange !== 0 && pedidoData.usuario_id) {
          const userRef = db.collection('usuarios').doc(pedidoData.usuario_id);
          batch.update(userRef, {
            'tokens_balance': admin.firestore.FieldValue.increment(tokensChange)
          });
          console.log(`Otorgados/Descontados ${tokensChange} tokens al usuario ${pedidoData.usuario_id}`);
        }
      }

      await batch.commit();
      console.log('Webhook procesado con éxito');
    } catch (error) {
      console.error('Error procesando webhook', error);
    }
  }
}
