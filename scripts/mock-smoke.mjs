const baseUrl = process.env.MOCK_API_URL ?? 'http://127.0.0.1:4010';

async function request(path, init = {}, expectedStatus) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(expectedStatus ? {Prefer: `code=${expectedStatus}`} : {}),
      ...init.headers,
    },
  });

  if (expectedStatus && response.status !== expectedStatus) {
    const body = await response.text();
    throw new Error(
      `${init.method ?? 'GET'} ${path}: expected ${expectedStatus}, ` +
        `received ${response.status} ${body}`,
    );
  }
  if (!expectedStatus && !response.ok && response.status !== 202) {
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

const authenticated = {Authorization: 'Bearer mock.access.token'};

await request('/categories', {headers: authenticated}, 200);
await request('/habits', {headers: authenticated}, 200);
await request(
  '/habits',
  {
    method: 'POST',
    headers: authenticated,
    body: JSON.stringify({
      nombre: 'Leer',
      descripcion: 'Veinte páginas',
      fechaInicio: '2026-07-28',
      categoriaId: 'cat_lectura',
      metaId: 'meta_001',
      frecuencia: {
        tipo: 'dias_semana',
        diasSemana: [1, 3, 5],
      },
    }),
  },
  201,
);
await request(
  '/habits',
  {
    method: 'POST',
    headers: authenticated,
    body: JSON.stringify({
      nombre: 'Frecuencia inválida',
      fechaInicio: '2026-07-28',
      frecuencia: {tipo: 'dias_semana', diasSemana: []},
    }),
  },
  400,
);
await request(
  '/habits/hab_001/pause',
  {
    method: 'POST',
    headers: authenticated,
    body: JSON.stringify({fechaInicio: '2026-07-28'}),
  },
  200,
);
await request(
  '/habits/hab_001/resume',
  {method: 'POST', headers: authenticated},
  200,
);
await request(
  '/habits/hab_001/complete',
  {method: 'POST', headers: authenticated},
  200,
);
await request(
  '/habits/hab_001',
  {method: 'DELETE', headers: authenticated},
  204,
);
await request('/goals', {headers: authenticated}, 200);
await request(
  '/goals',
  {
    method: 'POST',
    headers: authenticated,
    body: JSON.stringify({
      nombre: 'Dormir mejor',
      descripcion: 'Consolidar una rutina nocturna',
      fechaObjetivo: '2026-12-31',
      habitoIds: ['hab_001'],
    }),
  },
  201,
);
await request(
  '/goals/meta_001',
  {
    method: 'PATCH',
    headers: authenticated,
    body: JSON.stringify({
      nombre: 'Dormir mejor cada noche',
      estado: 'pausada',
    }),
  },
  200,
);
await request(
  '/goals/meta_001/habits/hab_001',
  {method: 'PUT', headers: authenticated},
  200,
);
await request(
  '/goals/meta_001/habits/hab_001',
  {method: 'DELETE', headers: authenticated},
  204,
);

console.log('Prism smoke test: Phase 1 + habits lifecycle + goals linking OK');
