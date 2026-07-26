const baseUrl = process.env.MOCK_API_URL ?? 'http://127.0.0.1:4010';

async function request(path, init = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...init.headers,
    },
  });

  if (!response.ok && response.status !== 202 && response.status !== 204) {
    const body = await response.text();
    throw new Error(`${init.method ?? 'GET'} ${path}: ${response.status} ${body}`);
  }
  return response;
}

await request('/auth/register', {
  method: 'POST',
  body: JSON.stringify({
    nombre: 'Camila Acevedo',
    email: 'camila@example.com',
    password: 'Segura123',
    aceptaTerminos: true,
    aceptaPrivacidad: true,
    versionTerminos: '2026-01',
    versionPrivacidad: '2026-01',
  }),
});

await request('/auth/login', {
  method: 'POST',
  body: JSON.stringify({
    email: 'camila@example.com',
    password: 'Segura123',
  }),
});

await request('/auth/password-reset/request', {
  method: 'POST',
  body: JSON.stringify({email: 'camila@example.com'}),
});

await request('/auth/password-reset/confirm', {
  method: 'POST',
  body: JSON.stringify({
    token: 'reset_eyJhbGciOiJIUzI1NiJ9',
    newPassword: 'NuevaSegura123',
  }),
});

const profileResponse = await request('/users/me', {
  headers: {Authorization: 'Bearer mock.access.token'},
});
const profile = await profileResponse.json();
for (const field of [
  'objetivoGeneral',
  'zonaHoraria',
  'accesibilidad',
  'notificaciones',
]) {
  if (!(field in profile)) {
    throw new Error(`GET /users/me no incluyó ${field}`);
  }
}

await request('/users/me', {
  method: 'PATCH',
  headers: {Authorization: 'Bearer mock.access.token'},
  body: JSON.stringify({
    nombreCompleto: 'Camila Acevedo',
    objetivoGeneral: 'Dormir mejor',
    zonaHoraria: 'America/Bogota',
    accesibilidad: {
      lectorTexto: false,
      tamanoTexto: 'mediano',
      altoContraste: false,
    },
    notificaciones: {
      habilitadas: true,
      recordatoriosHabitos: true,
      resumenSemanal: true,
    },
  }),
});

console.log('Prism smoke test: OK');
