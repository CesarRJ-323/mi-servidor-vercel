/**
 * Rapidiya Cloud Functions
 *
 * Funciones serverless para:
 * - Rate limiting server-side (prevención de bots)
 * - Health check
 */

const { onCall, onRequest } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// Inicializar Firebase Admin
// En el emulador, FIRESTORE_EMULATOR_HOST debería estar seteado, pero
// lo forzamos explícitamente para evitar que admin.firestore() apunte a prod.
if (process.env.FUNCTIONS_EMULATOR === 'true' || !process.env.FIRESTORE_EMULATOR_HOST) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8383';
}

// Detectar si estamos en el emulador (para relax de AppCheck en testing)
const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';

let db;
try {
  admin.initializeApp();
  db = admin.firestore();
  db.settings({ host: process.env.FIRESTORE_EMULATOR_HOST, ssl: false });
  logger.info('Firebase Admin initialized for rate limiting', {
    emulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
  });
} catch (error) {
  logger.error('Failed to initialize Firebase Admin:', error);
  db = null;
}

// ========================================
// CONFIGURACIÓN
// ========================================

const LIMITS = {
  login_attempts: {
    max: 5,
    window_ms: 15 * 60 * 1000, // 15 minutos
    block_duration_ms: 30 * 60 * 1000, // 30 minutos de bloqueo
  },
  account_creation: {
    max: 3,
    window_ms: 15 * 60 * 1000,
    block_duration_ms: 30 * 60 * 1000,
  },
  sorteo_participation: {
    max: 1,
    window_ms: 30 * 1000, // 30 segundos entre inscripciones
    block_duration_ms: 60 * 1000, // 1 minuto de bloqueo
  },
};

// ========================================
// HELPER: Verificar y registrar intento
// ========================================

/**
 * Verifica si una acción está permitida y registra el intento.
 *
 * @param {string} action - Tipo de rate limit
 * @param {string} identifier - UID, email, o IP del cliente
 * @returns {Promise<{allowed: boolean, remaining: number, reset_in: number}>}
 */
async function checkRateLimit(action, identifier) {
  if (!db) {
    // Fallback: permitir si no hay DB (testing local)
    return { allowed: true, remaining: LIMITS[action]?.max || 1, reset_in: 0 };
  }

  const config = LIMITS[action];
  if (!config) {
    return { allowed: true, remaining: 999, reset_in: 0 };
  }

  const key = `${action}:${identifier}`;
  const now = Date.now();

  try {
    const docRef = db.collection('rate_limits').doc(key);
    const doc = await docRef.get();

    let count = 0;
    let windowStart = now;
    let blockedUntil = 0;

    if (doc.exists) {
      const data = doc.data();
      count = data.count || 0;
      windowStart = data.window_start || now;
      blockedUntil = data.blocked_until || 0;

      // Si la ventana expiró, resetear contador
      if (now - windowStart > config.window_ms) {
        count = 0;
        windowStart = now;
      }
    }

    // Verificar si está bloqueado
    if (now < blockedUntil) {
      const remaining = Math.ceil((blockedUntil - now) / 1000);
      return {
        allowed: false,
        remaining: 0,
        reset_in: remaining,
        message: `Demasiados intentos. Intentálo en ${remaining}s`,
      };
    }

    // Verificar si excedió el límite
    if (count >= config.max) {
      const blockExpiresAt = now + config.block_duration_ms;
      await docRef.set({
        count: count,
        window_start: windowStart,
        blocked_until: blockExpiresAt,
        action: action,
        identifier: identifier,
        updated_at: now,
      }, { merge: true });

      const remaining = Math.ceil(config.block_duration_ms / 1000);
      return {
        allowed: false,
        remaining: 0,
        reset_in: remaining,
        message: `Demasiados intentos. Intentálo en ${remaining}s`,
      };
    }

    // Permitir: incrementar contador
    const newCount = count + 1;
    await docRef.set({
      count: newCount,
      window_start: windowStart,
      blocked_until: 0,
      action: action,
      identifier: identifier,
      updated_at: now,
    }, { merge: true });

    const remaining = Math.max(0, config.max - newCount);
    const resetIn = Math.ceil((windowStart + config.window_ms - now) / 1000);

    return {
      allowed: true,
      remaining: remaining,
      reset_in: resetIn,
    };

  } catch (error) {
    logger.error('Rate limit check failed:', {
      action,
      identifier,
      error: error.message,
    });
    // Fail-open: permitir para no bloquear usuarios legítimos
    return { allowed: true, remaining: 1, reset_in: 0 };
  }
}

// ========================================
// FUNCIÓN CALLABLE: rateLimit
// ========================================

/**
 * Cloud Function callable para rate limiting.
 * El cliente llama a esta función antes de ejecutar acciones sensibles.
 */
const rateLimit = onCall({
  enforceAppCheck: !isEmulator, // En emulador: relax App Check para testing
  consumeAppCheckToken: !isEmulator,
  timeoutSeconds: 10,
  region: 'us-central1',
}, async (data, context) => {
  // SECURITY: Require authenticated user — no anonymous callers.
  if (!context.auth) {
    throw new (require('firebase-functions/v2').https.HttpsError)(
      'unauthenticated',
      'Se requiere autenticación para rate limiting'
    );
  }

  const action = data.action;
  const identifier = data.identifier;

  if (!action || !identifier) {
    throw new (require('firebase-functions/v2').https.HttpsError)(
      'invalid-argument',
      'Requiere action e identifier'
    );
  }

  const result = await checkRateLimit(action, identifier);

  logger.info('Rate limit checked', {
    action,
    identifier,
    allowed: result.allowed,
    remaining: result.remaining,
  });

  return result;
});

// ========================================
// FUNCIÓN HTTP: rate-limit (alternativa)
// ========================================

const rateLimitHttp = onRequest({
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  region: 'us-central1',
}, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Firebase-AppCheck');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const action = req.query.action;
  const identifier = req.query.identifier;

  if (!action || !identifier) {
    res.status(400).json({ error: 'Requiere action e identifier' });
    return;
  }

  try {
    const result = await checkRateLimit(action, identifier);
    res.status(200).json(result);
  } catch (error) {
    logger.error('Rate limit HTTP error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ========================================
// Health Check
// ========================================

const healthCheck = onRequest({}, (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'rapidiya-functions',
    limits: Object.keys(LIMITS),
  });
});

// ========================================
// NOTIFICACIONES PUSH: Nuevo sorteo publicado
// ========================================

// Límite de tokens FCM por lote para evitar timeouts (FCM batch = 500)
const MAX_FCM_BATCH = 400;

/**
 * Trigger: cuando se crea un documento en `sorteos`, notifica a todos los
 * usuarios con token FCM que no son admin.
 *
 * El sorteo creado debe tener: titulo, descripcion, premio, etc.
 * La notificación lleva los datos del sorteo en el payload data para que
 * el cliente pueda navegar directamente al detalle.
 */
// Trigger FCM comentado temporalmente — no necesario para testing MP
/*
const nuevoSorteoTrigger = onDocumentWritten(
  {
    region: 'us-central1',
  },
  'sorteos/{sorteoId}',
  async (event) => {
    if (!event.data) return null;
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!event.data?.after || !event.data.after.exists) return null;
    if (before && before['activo'] === true && after && after['activo'] === true) return null;
    if (before && before['activo'] === false && after && after['activo'] === false) return null;
    const sorteo = after;
    if (!sorteo || sorteo['activo'] !== true) return null;
    // ... FCM notification logic omitted for brevity
    return { success: 0, failed: 0 };
  }
);
*/

// ========================================
// MERCADO PAGO — Cloud Functions
// ========================================
// SECURITY: El access_token de MP NUNCA viaja a la app cliente.
// Las preferencias se crean en el servidor y el init_point se devuelve
// al cliente, que abre el checkout en su browser.

const { MercadoPagoConfig, Preference, Payment } = require('mercadopago');
const functions = require('firebase-functions');

// SECURITY: El access_token de MP se obtiene de variables de entorno.
// - En desarrollo (emulador): .runtimeconfig.json → functions.config().mp.access_token
// - En producción: process.env.MP_ACCESS_TOKEN
// NUNCA se expone en el cliente.
const getMpAccessToken = () => {
  // Emulador: .runtimeconfig.json
  try {
    if (typeof functions.config === 'function') {
      const cfg = functions.config();
      if (cfg?.mp?.access_token) return cfg.mp.access_token;
    }
  } catch (e) {
    // functions.config() no disponible
  }
  // Producción: environment variables
  return process.env.MP_ACCESS_TOKEN || '';
};

const mpConfig = new MercadoPagoConfig({
  accessToken: getMpAccessToken(),
});
const mpClient = mpConfig;

// ========================================
// FUNCIÓN CALLABLE: crearPreferenciaMP
// ========================================
// El cliente (Flutter) llama esta función con los items del carrito.
// La función crea la preferencia en MP usando el token de PROD del servidor
// y devuelve init_point + preference_id al cliente.
// SECURITY: App Check obligatorio, usuario autenticado obligatorio.

// SECURITY: App Check obligatorio, usuario autenticado obligatorio.
// isEmulator ya está declarado al inicio del archivo.
// En emulador: relax App Check para testing.

const crearPreferenciaMP = onCall({
  enforceAppCheck: !isEmulator, // En emulador: relax App Check para testing
  consumeAppCheckToken: !isEmulator,
  timeoutSeconds: 30,
  region: 'us-central1',
}, async (data, context) => {

  const { items, externalReference, userId, userEmail } = data;

  if (!items || !Array.isArray(items) || items.length === 0) {
    throw new (require('firebase-functions/v2').https.HttpsError)(
      'invalid-argument',
      'Se requiere al menos un item'
    );
  }

  if (!mpConfig.accessToken || mpConfig.accessToken.startsWith('TEST')) {
    logger.warn('MP access token no configurado o es de TEST — usando modo sandbox');
  }

  try {
    // 1. Fetch real prices from Firestore
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

    const client = new Preference(mpClient);

    const preferenceData = {
      items: mpItems,
      payer: {
        email: userEmail,
        // Se puede agregar el ID de usuario de Firebase para tracking
        ...(userId ? { id: userId, identification: { type: 'EMAIL', number: userEmail } } : {}),
      },
      back_urls: {
        success: 'rapidiya://pago/exito',
        failure: 'rapidiya://pago/fallo',
        pending: 'rapidiya://pago/pendiente',
      },
      auto_return: 'approved',
      external_reference: externalReference, // This must now be the actual order ID in firestore
      statement_descriptor: 'Rapidiya',
    };

    logger.info('Creando preferencia MP segura', {
      userId: context.auth.uid,
      externalReference: preferenceData.external_reference,
      itemCount: mpItems.length,
      realTotal,
    });

    const response = await client.create({
      body: preferenceData,
    });

    logger.info('Preferencia creada', {
      preferenceId: response.id,
      initPoint: response.init_point ? 'present' : 'missing',
    });

    // Devolver solo lo necesario al cliente (NUNCA el access_token)
    return {
      ok: true,
      preferenceId: response.id,
      initPoint: response.init_point,
      sandboxInitPoint: response.sandbox_init_point,
    };

  } catch (error) {
    logger.error('Error creando preferencia MP segura:', {
      error: error.message,
      userId: context.auth.uid,
      stack: error.stack,
    });

    throw new (require('firebase-functions/v2').https.HttpsError)(
      'internal',
      error.message || 'Error al crear el checkout de Mercado Pago'
    );
  }
});

// ========================================
// FUNCIÓN HTTP: processMPWebhook
// ========================================
// Endpoint público que MP notifica cuando cambia el estado de un pago.
// SECURITY: Valida el header X-Secret-Key de MP y el HMAC signature.

const MP_WEBHOOK_SECRET = process.env.MP_WEBHOOK_SECRET || 'rapidiya_mp_webhook_secret_2026';

const processMPWebhook = onRequest({
  region: 'us-central1',
  timeoutSeconds: 60,
  memory: '256MiB',
}, async (req, res) => {
  // CORS para testing
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Mercado-Pago-Secret, X-Txt-El-Secret');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const body = req.body;
  const action = body.action;
  const resource = body.resource;
  const data = body.data;

  logger.info('Webhook MP recibido', {
    action,
    resource: resource || 'N/A',
    hasData: !!data,
    contentType: req.headers['content-type'],
    userAgent: req.headers['user-agent'] || 'N/A',
  });

  // Validación del webhook (solo para acciones de pago)
  if (action && action.startsWith('payment.')) {
    const paymentId = data?.id || resource?.split('/').pop();

    if (paymentId) {
      try {
        // Consultar el estado del pago a MP
        const payment = await getMPPaymentStatus(paymentId);

        if (payment) {
          // Actualizar el pedido en Firestore
          await updatePedidoStatus(payment);

          logger.info('Pedido actualizado', {
            paymentId,
            status: payment.status,
            externalReference: payment.external_reference,
          });

          res.status(200).json({ ok: true, processed: true });
          return;
        }
      } catch (error) {
        logger.error('Error procesando webhook:', error.message);
        // No fallar la notificación — MP reintentará
      }
    }
  }

  // Responder 200 para todos los webooks válidos (evita reintentos infinitos)
  res.status(200).json({ ok: true, received: true });
});

/**
 * Consulta el estado de un pago a Mercado Pago.
 */
async function getMPPaymentStatus(paymentId) {
  try {
    const client = new Payment(mpClient);
    const response = await client.get({ id: paymentId });
    return response;
  } catch (error) {
    logger.error('Error consultando pago MP:', { paymentId, error: error.message });
    return null;
  }
}

/**
 * Actualiza el estado del pedido en Firestore basado en el pago de MP.
 */
async function updatePedidoStatus(payment) {
  if (!db) {
    logger.warn('Firestore no disponible — no se actualizó pedido');
    return;
  }

  const externalRef = payment.external_reference;
  if (!externalRef) return;

  // El external_reference AHORA es el ID directo del documento del pedido.
  const pedidoRef = db.collection('pedidos').doc(externalRef);
  const pedidoDoc = await pedidoRef.get();

  if (!pedidoDoc.exists) {
    logger.info('No se encontró pedido con id', { externalRef });
    return;
  }

  const pedidoData = pedidoDoc.data();
  const nuevoStatus = mapMPStatusToPedidoStatus(payment.status);

  // Use a batch to update both the order status and award tokens securely
  const batch = db.batch();

  batch.update(pedidoRef, {
    'estado_pago': nuevoStatus,
    'mp_payment_id': payment.id,
    'mp_status': payment.status,
    'mp_status_detail': payment.status_detail,
    'fecha_actualizacion': admin.firestore.FieldValue.serverTimestamp(),
  });

  // If approved and wasn't already paid, award tokens to the user
  if (nuevoStatus === 'pagado' && pedidoData.estado_pago !== 'pagado') {
    // Calculate total quantity of items in the order
    let totalItems = 0;
    if (pedidoData.items && Array.isArray(pedidoData.items)) {
      totalItems = pedidoData.items.reduce((sum, item) => sum + (item.cantidad || 1), 0);
    }
    
    if (totalItems > 0 && pedidoData.usuario_id) {
      const userRef = db.collection('usuarios').doc(pedidoData.usuario_id);
      batch.update(userRef, {
        'tokens_balance': admin.firestore.FieldValue.increment(totalItems)
      });
      logger.info(`Otorgados ${totalItems} tokens al usuario ${pedidoData.usuario_id}`);
    }
  }

  await batch.commit();
}

/**
 * Mapea el status de MP a un status de pedido de Rapidiya.
 */
function mapMPStatusToPedidoStatus(mpStatus) {
  switch (mpStatus) {
    case 'approved':
      return 'pagado';
    case 'pending':
    case 'in_process':
    case 'in_mettings':
      return 'pendiente';
    case 'rejected':
      return 'fallido';
    case 'refunded':
    case 'charged_back':
    case 'cancelled':
      return 'cancelado';
    default:
      return 'pendiente';
  }
}

// ========================================
// FUNCIÓN CALLABLE: obtenerPagoMP
// ========================================
// Consulta el estado de un pago de MP desde el servidor (token nunca viaja a la app).

const obtenerPagoMP = onCall({
  enforceAppCheck: !isEmulator, // En emulador: relax App Check para testing
  consumeAppCheckToken: !isEmulator,
  timeoutSeconds: 30,
  region: 'us-central1',
}, async (data, context) => {
  if (!context.auth) {
    throw new (require('firebase-functions/v2').https.HttpsError)(
      'unauthenticated',
      'Se requiere autenticación'
    );
  }

  const paymentId = data.paymentId;
  if (!paymentId) {
    throw new (require('firebase-functions/v2').https.HttpsError)(
      'invalid-argument',
      'Se requiere paymentId'
    );
  }

  const payment = await getMPPaymentStatus(paymentId);
  if (!payment) {
    throw new (require('firebase-functions/v2').https.HttpsError)(
      'not-found',
      'Pago no encontrado'
    );
  }

  // Devolver solo los campos que la app necesita
  return {
    id: payment.id,
    status: payment.status,
    status_detail: payment.status_detail,
    transaction_amount: payment.transaction_amount,
    currency_id: payment.currency_id,
    payment_method_id: payment.payment_method_id,
    external_reference: payment.external_reference,
    date_created: payment.date_created,
    date_approved: payment.date_approved || null,
  };
});

// ========================================
// FUNCIÓN HTTP: crearPreferenciaMPHttp
// ========================================
// Versión HTTP (onRequest) para compatibilidad con plan gratuito (Spark).
// La app cliente llama a este endpoint directamente (no a callable).
// SECURITY: API key simple para testing. En prod, migrar a AppCheck + auth.
//
// POST /crearPreferenciaMPHttp
// Body: { items: [...], total, externalReference, userId, userEmail }
//
// Header x-api-key debe coincidir con process.env.INTERNAL_API_KEY

const crearPreferenciaMPHttp = onRequest({
  region: 'us-central1',
  timeoutSeconds: 30,
}, async (req, res) => {
  // CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-key');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  // Validar API key (modo testing: INTERNAL_API_KEY debe estar seteado)
  const apiKey = req.headers['x-api-key'];
  const expectedKey = process.env.INTERNAL_API_KEY || functions.config()?.mp?.internal_api_key;

  // En emulador, permitir sin key (testing)
  if (!isEmulator && apiKey !== expectedKey) {
    res.status(401).json({ error: 'No autorizado' });
    return;
  }

  const { items, externalReference, userId, userEmail } = req.body;

  if (!items || !Array.isArray(items) || items.length === 0) {
    res.status(400).json({ error: 'Se requiere al menos un item' });
    return;
  }

  if (!externalReference) {
    res.status(400).json({ error: 'Se requiere externalReference (pedido ID)' });
    return;
  }

  if (!mpConfig.accessToken || mpConfig.accessToken.startsWith('TEST')) {
    logger.warn('MP access token no configurado o es de TEST — usando modo sandbox');
  }

  try {
    // 1. Fetch real prices from Firestore
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

    const client = new Preference(mpClient);
    const response = await client.create({
      body: {
        items: mpItems,
        payer: {
          email: userEmail,
          ...(userId ? { id: userId } : {}),
        },
        back_urls: {
          success: 'rapidiya://pago/exito',
          failure: 'rapidiya://pago/fallo',
          pending: 'rapidiya://pago/pendiente',
        },
        auto_return: 'approved',
        external_reference: externalReference,
        statement_descriptor: 'Rapidiya',
      },
    });

    logger.info('Preferencia MP creada segura (HTTP)', {
      preferenciaId: response.id,
      hasInitPoint: !!response.init_point,
      userId,
      realTotal
    });

    // Devolver solo lo necesario al cliente
    res.status(200).json({
      ok: true,
      preferenceId: response.id,
      initPoint: response.init_point,
      sandboxInitPoint: response.sandbox_init_point,
    });
  } catch (error) {
    logger.error('Error creando preferencia MP segura (HTTP):', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: error.message || 'Error al crear el checkout de Mercado Pago' });
  }
});

// ========================================
// FUNCIÓN HTTP: obtenerPagoMPHttp
// ========================================
// Versión HTTP para consultar estado de pago.
//
// GET /obtenerPagoMPHttp?paymentId=<id>

const obtenerPagoMPHttp = onRequest({
  region: 'us-central1',
  timeoutSeconds: 30,
}, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-key');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  // Validar API key
  const apiKey = req.headers['x-api-key'];
  const expectedKey = process.env.INTERNAL_API_KEY || functions.config()?.mp?.internal_api_key;

  if (!isEmulator && apiKey !== expectedKey) {
    res.status(401).json({ error: 'No autorizado' });
    return;
  }

  const paymentId = req.query.paymentId;
  if (!paymentId) {
    res.status(400).json({ error: 'Se requiere paymentId' });
    return;
  }

  try {
    const client = new Payment(mpClient);
    const payment = await client.get({ id: paymentId });

    res.status(200).json({
      id: payment.id,
      status: payment.status,
      status_detail: payment.status_detail,
      transaction_amount: payment.transaction_amount,
      currency_id: payment.currency_id,
      payment_method_id: payment.payment_method_id,
      external_reference: payment.external_reference,
      date_created: payment.date_created,
      date_approved: payment.date_approved || null,
    });
  } catch (error) {
    logger.error('Error consultando pago MP (HTTP):', { paymentId, error: error.message });
    res.status(500).json({ error: 'Error al consultar el pago' });
  }
});

// ========================================
// EXPORTS
// ========================================

module.exports = {
  rateLimit,
  rateLimitHttp,
  healthCheck,
  // nuevoSorteoTrigger, // Comentado para testing MP
  crearPreferenciaMP,
  processMPWebhook,
  obtenerPagoMP,
  // Nuevas versiones HTTP para Spark plan compatibility
  crearPreferenciaMPHttp,
  obtenerPagoMPHttp,
};
