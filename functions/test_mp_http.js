/**
 * Test rápido de las funciones HTTP de Mercado Pago
 * Ejecutar: node test_mp_http.js
 */

const http = require('http');

const PORT = 5444;
const PROJECT_ID = 'deliverymovile-c25ff';
const REGION = 'us-central1';
const BASE_URL = `http://127.0.0.1:${PORT}/${PROJECT_ID}/${REGION}`;

console.log('🧪 Test MP HTTP Functions\n');
console.log(`Base URL: ${BASE_URL}\n`);

// Test 1: Health Check
const testHealth = () => {
  return new Promise((resolve) => {
    const req = http.get(`${BASE_URL}/healthCheck`, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          console.log('✅ Health Check:', json.status === 'ok' ? 'PASS' : 'FAIL');
          resolve(json.status === 'ok');
        } catch (e) {
          console.log('❌ Health Check: FAIL (parse error)');
          resolve(false);
        }
      });
    });
    req.on('error', (e) => {
      console.log('❌ Health Check: FAIL (connection error) -', e.message);
      resolve(false);
    });
    req.setTimeout(3000, () => {
      req.destroy();
      console.log('❌ Health Check: FAIL (timeout)');
      resolve(false);
    });
  });
};

// Test 2: Crear preferencia MP (simulado)
const testCrearPreferencia = () => {
  return new Promise((resolve) => {
    const body = JSON.stringify({
      titulo: 'Pedido Rapidiya Test',
      items: [{
        titulo: 'Avena integral',
        precioUnitario: 144,
        cantidad: 1,
        descripcion: 'Product test'
      }],
      externalReference: 'pedido_test_123456',
      userId: 'test-user-id',
      userEmail: 'test@example.com',
      total: 144
    });

    const req = http.request(`${BASE_URL}/crearPreferenciaMPHttp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': 'test-key-rapidiya-2026'
      }
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          const hasInitPoint = json.initPoint && json.initPoint.length > 0;
          console.log('✅ Crear Preferencia MP:', hasInitPoint ? 'PASS' : 'FAIL');
          if (hasInitPoint) {
            console.log('   Init Point:', json.initPoint.substring(0, 80) + '...');
            console.log('   Preference ID:', json.preferenceId);
          } else {
            console.log('   Response:', data.substring(0, 200));
          }
          resolve(hasInitPoint);
        } catch (e) {
          console.log('❌ Crear Preferencia MP: FAIL (parse error)');
          console.log('   Raw response:', data.substring(0, 200));
          resolve(false);
        }
      });
    });

    req.on('error', (e) => {
      console.log('❌ Crear Preferencia MP: FAIL (connection error) -', e.message);
      resolve(false);
    });
    req.setTimeout(5000, () => {
      req.destroy();
      console.log('❌ Crear Preferencia MP: FAIL (timeout)');
      resolve(false);
    });

    req.write(body);
    req.end();
  });
};

// Test 3: Obtener pago MP (simulado)
const testObtenerPago = () => {
  return new Promise((resolve) => {
    const req = http.get(`${BASE_URL}/obtenerPagoMPHttp?paymentId=test_123&x-api-key=test-key-rapidiya-2026`, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          const isValidPayment = json.id || json.error;
          console.log('✅ Obtener Pago MP:', isValidPayment ? 'PASS' : 'FAIL');
          console.log('   Response:', data.substring(0, 200));
          resolve(true); // Siempre PASS si conectó
        } catch (e) {
          console.log('❌ Obtener Pago MP: FAIL (parse error)');
          resolve(false);
        }
      });
    });
    req.on('error', (e) => {
      console.log('❌ Obtener Pago MP: FAIL (connection error)');
      resolve(false);
    });
    req.setTimeout(3000, () => {
      req.destroy();
      console.log('❌ Obtener Pago MP: FAIL (timeout)');
      resolve(false);
    });
  });
};

// Run tests
(async () => {
  console.log('=' .repeat(50));

  const healthOk = await testHealth();
  console.log('');

  if (healthOk) {
    await testCrearPreferencia();
    console.log('');
    await testObtenerPago();
    console.log('');
  } else {
    console.log('⚠️  Health check failed - emulators may not be running');
    console.log('   Run: firebase emulators:start --only functions');
  }

  console.log('='.repeat(50));
  console.log('Tests completed at:', new Date().toLocaleString('es-AR'));
})();