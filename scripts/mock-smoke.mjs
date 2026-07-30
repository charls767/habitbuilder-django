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
  200,
);

const remindersResponse = await request(
  '/habits/hab_001/reminders',
  {headers: authenticated},
  200,
);
const reminders = await remindersResponse.json();
if (!Array.isArray(reminders) || reminders.length < 2) {
  throw new Error(
    'GET /habits/hab_001/reminders no expuso varios recordatorios',
  );
}
for (const reminder of reminders) {
  for (const field of ['mensaje', 'hora', 'diasSemana', 'activo']) {
    if (!(field in reminder)) {
      throw new Error(`GET reminders no incluyó ${field}`);
    }
  }
}

await request(
  '/habits/hab_001/reminders',
  {
    method: 'POST',
    headers: authenticated,
    body: JSON.stringify({
      mensaje: 'Hora de leer',
      hora: '07:00',
      diasSemana: [1, 3, 5],
      activo: true,
    }),
  },
  201,
);
await request(
  '/reminders/rec_001',
  {
    method: 'PATCH',
    headers: authenticated,
    body: JSON.stringify({
      mensaje: 'Lee veinte páginas',
      hora: '07:30',
      diasSemana: [1, 3, 5],
      activo: true,
    }),
  },
  200,
);
await request(
  '/reminders/rec_001',
  {
    method: 'PATCH',
    headers: authenticated,
    body: JSON.stringify({
      mensaje: 'Lee veinte páginas',
      hora: '07:30',
      diasSemana: [1, 3, 5],
      activo: false,
    }),
  },
  200,
);

const trackingResponse = await request(
  '/habits/hab_001/logs?desde=2026-07-30&hasta=2026-07-30',
  {headers: authenticated},
  200,
);
const trackingRecords = await trackingResponse.json();
if (!Array.isArray(trackingRecords)) {
  throw new Error('GET /habits/hab_001/logs no devolvio una lista');
}

const trackingRequest = {
  method: 'POST',
  headers: {
    ...authenticated,
    'Idempotency-Key': 'hab_001:2026-07-30',
  },
  body: JSON.stringify({
    fecha: '2026-07-30',
    estado: 'parcial',
    nota: 'Sesion completada parcialmente',
  }),
};
const createdTrackingResponse = await request(
  '/habits/hab_001/logs',
  trackingRequest,
  201,
);
const createdTracking = await createdTrackingResponse.json();
for (const field of ['id', 'habitoId', 'fecha', 'estado']) {
  if (!(field in createdTracking)) {
    throw new Error(`POST tracking no incluyo ${field}`);
  }
}
await request('/habits/hab_001/logs', trackingRequest, 200);

const progressResponse = await request(
  '/progress?periodo=semana',
  {headers: authenticated},
  200,
);
const progress = await progressResponse.json();
for (const field of [
  'periodo',
  'desde',
  'hasta',
  'porcentajeCumplimiento',
  'rachaActual',
  'rachaMasLarga',
  'completados',
  'programados',
  'dias',
]) {
  if (!(field in progress)) {
    throw new Error(`GET progress no incluyo ${field}`);
  }
}

const statisticsResponse = await request(
  '/statistics?periodo=semana&habitId=hab_001&categoryId=cat_001',
  {headers: authenticated},
  200,
);
const statistics = await statisticsResponse.json();
for (const field of [
  'periodo',
  'desde',
  'hasta',
  'porcentajeCumplimiento',
  'mejorRacha',
  'suficientesDatos',
  'habitos',
]) {
  if (!(field in statistics)) {
    throw new Error(`GET statistics no incluyo ${field}`);
  }
}

console.log(
  'Prism smoke test: auth + habits + goals + reminders + tracking + progress + statistics OK',
);
