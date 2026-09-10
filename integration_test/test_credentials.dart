// Helper de credenciales para tests (NO commitear valores reales).
// Uso: flutter test --dart-define=TEST_ADMIN_EMAIL=... --dart-define=TEST_ADMIN_PASS=...
//
// Los defaults de abajo son para DESARROLLO LOCAL solamente.
// Nunca usar credenciales reales como default.
const testAdminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL',
    defaultValue: 'test@example.com');
const testAdminPass = String.fromEnvironment('TEST_ADMIN_PASS',
    defaultValue: 'TestPass123');
const testClienteEmail = String.fromEnvironment('TEST_CLIENTE_EMAIL',
    defaultValue: 'cliente@example.com');
const testClientePass = String.fromEnvironment('TEST_CLIENTE_PASS',
    defaultValue: 'ClientePass123');
