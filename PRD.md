# Agua Segura — PRD (documento de producto)

*26 jul 2026 · para aprobación de Toño*

> **Protegemos tu hogar desde lo más alto.**
> *Confianza que se ve, protección que se siente.*

---

## 1. Para quién es

Para el negocio de lavado de tinacos y mantenimiento integral de tu familiar. Lo usan
**tres personas**: él (dueño) y sus **dos técnicos**.

**Esta es la app del NEGOCIO**, no la del cliente final. Decisión tomada contigo: la del
cliente vendrá después, cuando haya flujo suficiente para que valga la pena que la
instalen. Mientras tanto, el cliente recibe todo por WhatsApp sin instalar nada.

Se construye **multiempresa desde el arranque**: tu familiar es la empresa #1, y si mañana
quieres vendérsela a otros negocios del mismo giro, ya está lista. No cuesta trabajo extra.

---

## 2. El problema que resuelve

Se lo preguntamos directo y contestó sin dudar:

> **"Se me olvida a quién le toca renovar o hacer el mantenimiento de 6 meses."**

Eso es **dinero que se va**. Un tinaco se lava cada 6 meses; si nadie avisa, el cliente
simplemente no vuelve a llamar — no porque quedara mal, sino porque se le pasó. Cada
cliente olvidado es un trabajo perdido, dos veces al año, para siempre.

Y como los clientes llegan **por recomendación**, cada uno vale más de lo normal: costó
una recomendación conseguirlo.

---

## 3. La función estrella: **¿A QUIÉN LE TOCA?**

Es la pantalla principal y el botón que manda. Al abrir la app, lo primero que ve es la
lista de clientes a los que **ya les toca** o **está por tocarles**, ordenados por urgencia:

```
   🔴  Vencidos          Sra. Martínez · tinacos · van 7 meses
   🟡  Esta semana       Depto. Las Flores · tinacos · en 3 días
   🟢  Este mes          Sr. Ramírez · impermeabilización · en 18 días
```

Junto a cada uno, **un botón que abre WhatsApp con el mensaje ya escrito**:

> *"Buen día, Sra. Martínez. Le escribimos de Agua Segura. Ya se cumplieron 6 meses del
> lavado de su tinaco (última vez: 15 de enero). ¿Le agendamos su servicio esta semana?"*

Él solo revisa y le da enviar. **Eso es todo el producto.** Lo demás existe para alimentar
esa pantalla.

### Por qué cada servicio tiene su propio plazo

No todo se renueva igual, así que cada tipo trae su periodicidad por defecto (editable):

| Servicio | Se repite cada |
|---|---|
| 💧 Lavado y desinfección de tinacos | **6 meses** |
| ☀️ Mantenimiento de calentadores solares | 12 meses |
| 🏠 Mantenimiento de techos | 12 meses |
| 🧱 Impermeabilización de azotea | 24 meses |
| 🔧 Plomería | No aplica (es correctivo, no preventivo) |

---

## 4. La segunda función: **el certificado que se ve**

El cliente nunca ve su tinaco por dentro: paga por fe. La app lo resuelve.

El técnico toma **foto del antes y del después** desde su celular, y al terminar el
servicio la app arma un **certificado** con:

- Fotos antes y después
- Fecha, dirección y tipo de servicio
- Quién lo realizó
- Próxima fecha recomendada

Se manda por WhatsApp con un toque. Sirve para dos cosas: al dueño de casa le da
tranquilidad, y a **restaurantes, escuelas, oficinas y guarderías** les sirve de
comprobante sanitario — que es justo la clientela que paga mejor y repite sola.

---

## 5. Qué maneja la app (MVP)

1. **Clientes** — nombre, teléfono (WhatsApp), dirección y referencias para llegar.
2. **Servicios realizados** — qué se hizo, cuándo, quién lo hizo, cuánto se cobró y si ya
   está pagado. Con sus fotos de antes y después.
3. **¿A quién le toca?** — la pantalla estrella, con el mensaje de WhatsApp listo.
4. **Agenda del día** — qué visitas hay hoy y quién las atiende.
5. **Certificado de servicio** — se genera y se comparte por WhatsApp.
6. **Corte de caja** — cuánto se cobró en el día/semana y qué falta por cobrar. Todo en
   efectivo, sin complicaciones ni tarjetas.
7. **Los tres usuarios** con sus permisos:
   - **Dueño**: ve todo, incluido el dinero.
   - **Técnico**: ve su agenda, registra el servicio y sube fotos. **No ve la caja.**

### Fuera del MVP (para después)

| Después | Por qué |
|---|---|
| App para el cliente final (la de tu imagen) | Necesita que la instalen: es problema de publicidad, no de código |
| Cobro con tarjeta | Hoy todo es efectivo |
| Rutas y mapa | Con 3 personas y clientes por recomendación, todavía no hace falta |
| Inventario de material (cloro, impermeabilizante) | Se puede agregar cuando lo pidan |

---

## 6. Cómo se usa (el día a día)

**El dueño, en la mañana:** abre la app y ve a quién le toca. Manda tres WhatsApps.
Agenda las visitas y se las asigna a sus técnicos.

**El técnico, en la azotea:** abre su agenda, ve la dirección y las referencias. Toma la
foto del antes, hace el trabajo, toma la del después, anota cuánto cobró y le da a
terminar. **Funciona sin internet** — en las azoteas la señal es mala — y se sincroniza
solo cuando vuelve a haber señal.

**El dueño, en la tarde:** ve cuánto se cobró y qué quedó pendiente, y manda los
certificados.

---

## 7. Cómo se entrega

| Para quién | Qué |
|---|---|
| **Los técnicos** | App de Android instalable. Funciona sin internet (las azoteas no tienen señal) |
| **El dueño** | La misma app, y además un panel web para ver todo en pantalla grande |
| **El cliente final** | Nada que instalar: recibe su certificado y su recordatorio por WhatsApp |

---

## 8. Marca

Ya está resuelta: logo, colores (azul marino y azul brillante sobre blanco) y eslogan.
Solo hace falta que me pases **el logo en archivo** para generar el ícono y la pantalla de
bienvenida.

---

## 9. Lo que necesito de ti

1. **Aprobar este PRD** o decirme qué cambiar.
2. **El logo en archivo** (PNG, lo más grande que tengas).
3. Más adelante, para publicarlo: las mismas cuentas de siempre (GitHub, Neon, Render,
   Vercel).

---

## 10. Si apruebas, el orden es este

1. Servidor con clientes, servicios y el cálculo de "a quién le toca"
2. App móvil: agenda del técnico, fotos antes/después, y la pantalla estrella
3. WhatsApp: recordatorio y certificado
4. Panel web y corte de caja
5. Marca y publicación

**¿Le damos, o cambiamos algo?**
