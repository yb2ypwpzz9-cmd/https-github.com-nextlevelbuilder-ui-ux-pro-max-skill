# Spado Rackets — web app (prototipo)

Archivo: `spado-rackets.html` (un solo HTML, sin build). Se abre desde cualquier navegador y se puede "Añadir a pantalla de inicio" en el móvil.

## Qué incluye

| Perfil | Funciones |
|---|---|
| **Dirección** | Panel (staff en pista, asistencia, justificantes por revisar, cuotas vencidas) · Fichajes de todo el staff (horas semana/mes) · Asistencia por grupo y alumna · Pagos: validar/rechazar justificantes, marcar pagada, editar datos bancarios · Chat (todos los canales) |
| **Staff** | Fichar entrada/salida con contador · Pasar lista por grupo y fecha (P / A / J), con faltas avisadas por las familias ya marcadas · Chat |
| **Familias** | Ficha de la alumna y % de asistencia · Avisar de una falta · Datos bancarios con IBAN y concepto copiables · Cuotas (pagada / pendiente / en revisión / rechazada) · Adjuntar justificante (imagen o PDF) · Chat |

Canales de chat: *Avisos del club* (solo publican dirección y staff), *Equipo técnico* (solo staff y dirección), uno por grupo (familias del grupo + entrenador) y uno privado por familia con dirección.

## Limitación importante

Los datos se guardan en `localStorage` del navegador: **cada dispositivo ve sus propios datos**. Sirve para validar flujos y pantallas con dirección, entrenadores y algunas familias, no para operar.

## Paso a producción (recomendado)

1. **Backend: Supabase** (Postgres + Auth + Storage + Realtime, plan gratuito suficiente para empezar).
   - Tablas: `profiles(role)`, `groups`, `students`, `family_students`, `clock_entries`, `attendance`, `fees`, `receipts`, `channels`, `channel_members`, `messages`, `absences`, `settings(bank)`.
   - Row Level Security por rol: una familia solo lee sus alumnas, sus cuotas y sus canales.
   - Storage privado para justificantes (URLs firmadas).
   - Realtime para el chat.
2. **Login** con email (magic link); dirección da de alta a staff y familias.
3. **Hosting**: Vercel o Netlify con dominio propio (p. ej. `app.spadorackets.com`). PWA con manifest + service worker para instalar en el móvil y recibir notificaciones push.
4. **Sustituir** la capa `load()/save()` del HTML por llamadas a Supabase.

## Cumplimiento (España)

- **Registro de jornada** (art. 34.9 ET): los fichajes deben conservarse 4 años, no ser editables sin rastro y estar a disposición de la plantilla y la Inspección. En producción: correcciones solo por dirección y con historial.
- **RGPD / menores**: datos de alumnas menores y justificantes bancarios → consentimiento de las familias, cláusula informativa, acceso limitado por rol y servidor en la UE.
