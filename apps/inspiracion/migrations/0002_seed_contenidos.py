"""Seed del catálogo de inspiración.

Réplica exacta de la migración Go 0015_seed_contenidos_inspiracion: mismo
SQL, mismos UUIDs, para que ambos backends produzcan datos idénticos.
"""
from django.db import migrations

SEED_UP = r"""INSERT INTO contenidos_inspiracion (
    id, tipo, titulo, resumen, url, imagen_url, autor, destacado, publicado,
    creado_en, actualizado_en
) VALUES
    (
        '7f2d9c8e-3a14-4b7c-9d21-6f8e5a2c1b40', 'articulo',
        'Cómo crear un hábito que realmente dure',
        'Conoce un método sencillo para elegir una señal, reducir la fricción y celebrar avances pequeños sin perder la constancia. Lectura de 5 minutos.',
        'https://contenido.habitbuilder.app/articulos/como-crear-un-habito-que-realmente-dure',
        'https://cdn.habitbuilder.app/inspiracion/como-crear-un-habito-que-realmente-dure.jpg',
        'Dra. Ana Soto', true, true, '2026-07-20T13:00:00Z', '2026-07-20T13:00:00Z'
    ),
    (
        '1a6e4c92-7b35-4d81-a2f9-8c0e5b3d7a14', 'video',
        'La ciencia detrás de la motivación',
        'Una explicación clara sobre recompensa, progreso visible y contexto para sostener la motivación cuando la novedad desaparece. Video de 8 minutos.',
        'https://contenido.habitbuilder.app/videos/la-ciencia-detras-de-la-motivacion',
        'https://cdn.habitbuilder.app/inspiracion/la-ciencia-detras-de-la-motivacion.jpg',
        'Dr. Mateo Ríos', false, true, '2026-07-19T13:00:00Z', '2026-07-19T13:00:00Z'
    ),
    (
        '3c8b1e75-2d46-4f90-b6a1-5e7c9d0a2f83', 'audio',
        'Meditación guiada para empezar el día',
        'Una práctica breve de respiración y atención plena para iniciar la mañana con calma, claridad y una intención concreta. Audio de 12 minutos.',
        'https://contenido.habitbuilder.app/audios/meditacion-guiada-para-empezar-el-dia',
        'https://cdn.habitbuilder.app/inspiracion/meditacion-guiada-para-empezar-el-dia.jpg',
        'Clara Méndez', false, true, '2026-07-18T13:00:00Z', '2026-07-18T13:00:00Z'
    ),
    (
        '5e1a7d39-9c24-4b68-8f02-3d6e5a1c7b94', 'articulo',
        '7 hábitos para dormir mejor',
        'Descubre ajustes prácticos para preparar tu habitación, reducir estímulos y construir una rutina nocturna que favorezca el descanso. Lectura de 4 minutos.',
        'https://contenido.habitbuilder.app/articulos/7-habitos-para-dormir-mejor',
        'https://cdn.habitbuilder.app/inspiracion/7-habitos-para-dormir-mejor.jpg',
        'Laura Vidal', false, true, '2026-07-17T13:00:00Z', '2026-07-17T13:00:00Z'
    ),
    (
        '8b4f2c16-6d93-4a57-9e20-1c7b5d8f3a46', 'video',
        'Rutina de movilidad para empezar el día',
        'Sigue una secuencia suave para despertar articulaciones, mejorar la postura y preparar el cuerpo para las actividades diarias. Video de 7 minutos.',
        'https://contenido.habitbuilder.app/videos/rutina-de-movilidad-para-empezar-el-dia',
        'https://cdn.habitbuilder.app/inspiracion/rutina-de-movilidad-para-empezar-el-dia.jpg',
        'Elena Torres', false, true, '2026-07-16T13:00:00Z', '2026-07-16T13:00:00Z'
    ),
    (
        '2d9a6e41-5b78-4c03-a6f2-8e1d7b4c9a25', 'audio',
        'Pausa de respiración para recuperar el foco',
        'Detén el ritmo por unos minutos y usa la respiración como ancla para volver a la tarea con mayor presencia y menos tensión. Audio de 6 minutos.',
        'https://contenido.habitbuilder.app/audios/pausa-de-respiracion-para-recuperar-el-foco',
        'https://cdn.habitbuilder.app/inspiracion/pausa-de-respiracion-para-recuperar-el-foco.jpg',
        'Nicolás Vera', false, true, '2026-07-15T13:00:00Z', '2026-07-15T13:00:00Z'
    ),
    (
        '4f7c2a90-1e65-4b38-b9d4-6a0f3c8e2d71', 'articulo',
        'Diseña una rutina de lectura que puedas mantener',
        'Aprende a escoger un momento realista, preparar el entorno y registrar páginas para convertir la lectura en un ritual agradable. Lectura de 6 minutos.',
        'https://contenido.habitbuilder.app/articulos/disena-una-rutina-de-lectura-que-puedas-mantener',
        'https://cdn.habitbuilder.app/inspiracion/disena-una-rutina-de-lectura-que-puedas-mantener.jpg',
        'Marina Soler', false, true, '2026-07-14T13:00:00Z', '2026-07-14T13:00:00Z'
    ),
    (
        '6a3e8d52-4c19-4f76-82b5-9d1c7a0e5f34', 'video',
        'Entrena tu concentración en bloques breves',
        'Una guía visual para trabajar con bloques de atención, pausas intencionales y un cierre que facilite retomar el trabajo al día siguiente. Video de 9 minutos.',
        'https://contenido.habitbuilder.app/videos/entrena-tu-concentracion-en-bloques-breves',
        'https://cdn.habitbuilder.app/inspiracion/entrena-tu-concentracion-en-bloques-breves.jpg',
        'Julián Campos', false, true, '2026-07-13T13:00:00Z', '2026-07-13T13:00:00Z'
    ),
    (
        '9c1b5e73-8a26-4d04-a7f9-2e6c0b5d1a48', 'audio',
        'Visualización de metas con calma',
        'Imagina el siguiente paso de una meta y conéctalo con una acción concreta para transformar una intención amplia en movimiento cotidiano. Audio de 10 minutos.',
        'https://contenido.habitbuilder.app/audios/visualizacion-de-metas-con-calma',
        'https://cdn.habitbuilder.app/inspiracion/visualizacion-de-metas-con-calma.jpg',
        'Sofía León', false, true, '2026-07-12T13:00:00Z', '2026-07-12T13:00:00Z'
    ),
    (
        'b2e7c491-3d58-4a26-9f80-6b1c5e8d0a37', 'articulo',
        'La regla de los dos minutos para comenzar',
        'Convierte una tarea que estás evitando en una primera acción tan pequeña que puedas iniciarla ahora y construir impulso sin presión. Lectura de 3 minutos.',
        'https://contenido.habitbuilder.app/articulos/la-regla-de-los-dos-minutos-para-comenzar',
        'https://cdn.habitbuilder.app/inspiracion/la-regla-de-los-dos-minutos-para-comenzar.jpg',
        'Pablo Ferrer', false, true, '2026-07-11T13:00:00Z', '2026-07-11T13:00:00Z'
    ),
    (
        'd4a9f263-1c70-4b85-a6e2-9f3d7c0b5a18', 'video',
        'Respiración consciente para reducir la tensión',
        'Practica una técnica sencilla para reconocer la tensión corporal, alargar la exhalación y recuperar un ritmo más sereno durante el día. Video de 6 minutos.',
        'https://contenido.habitbuilder.app/videos/respiracion-consciente-para-reducir-la-tension',
        'https://cdn.habitbuilder.app/inspiracion/respiracion-consciente-para-reducir-la-tension.jpg',
        'Valeria Cruz', false, true, '2026-07-10T13:00:00Z', '2026-07-10T13:00:00Z'
    ),
    (
        'e6c2b874-5a31-4d09-8f67-1b4e9c0a2d53', 'audio',
        'Relajación guiada para cerrar el día',
        'Baja gradualmente la actividad mental con un recorrido de atención por el cuerpo y una respiración lenta antes de dormir. Audio de 15 minutos.',
        'https://contenido.habitbuilder.app/audios/relajacion-guiada-para-cerrar-el-dia',
        'https://cdn.habitbuilder.app/inspiracion/relajacion-guiada-para-cerrar-el-dia.jpg',
        'Camila Duarte', false, true, '2026-07-09T13:00:00Z', '2026-07-09T13:00:00Z'
    ),
    (
        'f8d5a106-7c42-4b93-ae18-3f6d0c9b5e27', 'articulo',
        'Planifica tu semana con intención',
        'Organiza prioridades, espacios de descanso y hábitos esenciales con una revisión breve que convierta tu calendario en una guía flexible. Lectura de 7 minutos.',
        'https://contenido.habitbuilder.app/articulos/planifica-tu-semana-con-intencion',
        'https://cdn.habitbuilder.app/inspiracion/planifica-tu-semana-con-intencion.jpg',
        'Andrés Molina', false, true, '2026-07-08T13:00:00Z', '2026-07-08T13:00:00Z'
    ),
    (
        '0a7e3c95-6b14-4d82-9f30-5c1d8b6a2e47', 'articulo',
        'Prepara tu espacio para leer más',
        'Mira cómo pequeñas decisiones sobre luz, postura y distracciones pueden hacer que abrir un libro sea la opción más fácil. Lectura de 5 minutos.',
        'https://contenido.habitbuilder.app/articulos/prepara-tu-espacio-para-leer-mas',
        'https://cdn.habitbuilder.app/inspiracion/prepara-tu-espacio-para-leer-mas.jpg',
        'Teresa Pardo', false, true, '2026-07-07T13:00:00Z', '2026-07-07T13:00:00Z'
    ),
    (
        '2c9f5b08-4e63-4a17-9d0a-3c6e8f21b5a4', 'audio',
        'Lectura consciente para descansar la mente',
        'Acompaña una lectura pausada con atención a la respiración y deja que el cambio de ritmo prepare tu mente para una noche tranquila. Audio de 11 minutos.',
        'https://contenido.habitbuilder.app/audios/lectura-consciente-para-descansar-la-mente',
        'https://cdn.habitbuilder.app/inspiracion/lectura-consciente-para-descansar-la-mente.jpg',
        'Irene Salas', false, true, '2026-07-06T13:00:00Z', '2026-07-06T13:00:00Z'
    ),
    (
        '4e1b7d32-9a56-4c80-b3f2-6d0e8a5c1b74', 'articulo',
        'Pequeños cambios para cuidar tu energía',
        'Identifica los momentos de mayor cansancio y ajusta pausas, hidratación, movimiento y expectativas para proteger tu energía sin complicar tu rutina. Lectura de 5 minutos.',
        'https://contenido.habitbuilder.app/articulos/pequenos-cambios-para-cuidar-tu-energia',
        'https://cdn.habitbuilder.app/inspiracion/pequenos-cambios-para-cuidar-tu-energia.jpg',
        'Rocío Beltrán', false, true, '2026-07-05T13:00:00Z', '2026-07-05T13:00:00Z'
    ),
    (
        '6f3a8c19-2d75-4e04-9b61-5a7c0e3d8f26', 'video',
        'Cierre del día para dormir con menos pendientes',
        'Aprende un ritual corto para revisar avances, anotar pendientes y liberar espacio mental antes de apagar las luces. Video de 7 minutos.',
        'https://contenido.habitbuilder.app/videos/cierre-del-dia-para-dormir-con-menos-pendientes',
        'https://cdn.habitbuilder.app/inspiracion/cierre-del-dia-para-dormir-con-menos-pendientes.jpg',
        'Héctor Linares', false, true, '2026-07-04T13:00:00Z', '2026-07-04T13:00:00Z'
    ),
    (
        '8d5c2e47-1a90-4b63-a7f8-3c0e6b9d2f15', 'audio',
        'Enfoque profundo para una tarea importante',
        'Prepara tu atención con una breve guía sonora que ayuda a elegir una prioridad y sostener un bloque de trabajo sin interrupciones. Audio de 9 minutos.',
        'https://contenido.habitbuilder.app/audios/enfoque-profundo-para-una-tarea-importante',
        'https://cdn.habitbuilder.app/inspiracion/enfoque-profundo-para-una-tarea-importante.jpg',
        'Daniela Fuentes', false, true, '2026-07-03T13:00:00Z', '2026-07-03T13:00:00Z'
    ),
    (
        'a1e7b4c3-0d62-4f95-8b02-9c5a1e7d3f64', 'articulo',
        'Diario de gratitud para reconocer avances',
        'Usa tres preguntas sencillas para registrar lo que funcionó, valorar el esfuerzo y encontrar señales de progreso en días normales. Lectura de 4 minutos.',
        'https://contenido.habitbuilder.app/articulos/diario-de-gratitud-para-reconocer-avances',
        'https://cdn.habitbuilder.app/inspiracion/diario-de-gratitud-para-reconocer-avances.jpg',
        'Marta Quiroga', false, true, '2026-07-02T13:00:00Z', '2026-07-02T13:00:00Z'
    ),
    (
        'c3f9d6a1-8b47-4e70-a5c1-8d0f3b6e9a25', 'video',
        'Cómo convertir una meta en acciones diarias',
        'Observa un ejemplo práctico para dividir una meta, escoger una acción mínima y revisar el avance sin depender de la perfección. Video de 10 minutos.',
        'https://contenido.habitbuilder.app/videos/como-convertir-una-meta-en-acciones-diarias',
        'https://cdn.habitbuilder.app/inspiracion/como-convertir-una-meta-en-acciones-diarias.jpg',
        'Bruno Salcedo', false, true, '2026-07-01T13:00:00Z', '2026-07-01T13:00:00Z'
    ),
    (
        'e5a2c7b4-9f13-4d66-b0e4-1a9c5d7f2b38', 'articulo',
        'Movimiento cotidiano sin complicaciones',
        'Encuentra formas simples de sumar movimiento a tus trayectos, pausas y tareas para cuidar tu cuerpo con hábitos que caben en cualquier agenda. Lectura de 5 minutos.',
        'https://contenido.habitbuilder.app/articulos/movimiento-cotidiano-sin-complicaciones',
        'https://cdn.habitbuilder.app/inspiracion/movimiento-cotidiano-sin-complicaciones.jpg',
        'Gabriela Navas', false, true, '2026-06-30T13:00:00Z', '2026-06-30T13:00:00Z'
    )
ON CONFLICT (id) DO NOTHING;
"""

SEED_DOWN = r"""DELETE FROM contenidos_inspiracion
WHERE id IN (
    '7f2d9c8e-3a14-4b7c-9d21-6f8e5a2c1b40',
    '1a6e4c92-7b35-4d81-a2f9-8c0e5b3d7a14',
    '3c8b1e75-2d46-4f90-b6a1-5e7c9d0a2f83',
    '5e1a7d39-9c24-4b68-8f02-3d6e5a1c7b94',
    '8b4f2c16-6d93-4a57-9e20-1c7b5d8f3a46',
    '2d9a6e41-5b78-4c03-a6f2-8e1d7b4c9a25',
    '4f7c2a90-1e65-4b38-b9d4-6a0f3c8e2d71',
    '6a3e8d52-4c19-4f76-82b5-9d1c7a0e5f34',
    '9c1b5e73-8a26-4d04-a7f9-2e6c0b5d1a48',
    'b2e7c491-3d58-4a26-9f80-6b1c5e8d0a37',
    'd4a9f263-1c70-4b85-a6e2-9f3d7c0b5a18',
    'e6c2b874-5a31-4d09-8f67-1b4e9c0a2d53',
    'f8d5a106-7c42-4b93-ae18-3f6d0c9b5e27',
    '0a7e3c95-6b14-4d82-9f30-5c1d8b6a2e47',
    '2c9f5b08-4e63-4a17-9d0a-3c6e8f21b5a4',
    '4e1b7d32-9a56-4c80-b3f2-6d0e8a5c1b74',
    '6f3a8c19-2d75-4e04-9b61-5a7c0e3d8f26',
    '8d5c2e47-1a90-4b63-a7f8-3c0e6b9d2f15',
    'a1e7b4c3-0d62-4f95-8b02-9c5a1e7d3f64',
    'c3f9d6a1-8b47-4e70-a5c1-8d0f3b6e9a25',
    'e5a2c7b4-9f13-4d66-b0e4-1a9c5d7f2b38'
);
"""


class Migration(migrations.Migration):
    dependencies = [
        ("inspiracion", "0001_initial"),
    ]

    operations = [
        migrations.RunSQL(sql=SEED_UP, reverse_sql=SEED_DOWN),
    ]
