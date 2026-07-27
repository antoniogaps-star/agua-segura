# Publicar Agua Segura

Guía para dejar la app en internet. Son cuatro servicios gratuitos, los mismos de las
otras apps. Toma unos 30 minutos la primera vez.

> **Seguridad:** las contraseñas, tokens y la URL de la base **nunca** se pegan en el
> chat. Van directo del panel del proveedor a donde toca.

---

## 1. GitHub — el repositorio

1. Crear un repositorio **privado** llamado `agua-segura` en la cuenta de Toño.
2. Desde la carpeta del proyecto:

```bash
git remote add origin https://github.com/antoniogaps-star/agua-segura.git
```

```bash
git push -u origin main
```

Al terminar el push, GitHub Actions compila el APK solo. Queda en **Releases** con un
enlace fijo que nunca cambia:

`https://github.com/antoniogaps-star/agua-segura/releases/latest/download/agua-segura.apk`

Para compartirlo con la gente **no se usa ese enlace**, sino el corto:

`https://agua-segura.vercel.app/app`

Es una redirección definida en `web/vercel.json`. Se hizo así por tres razones: se dicta
por teléfono sin equivocarse, hace un código QR más simple de escanear, y si algún día el
archivo cambia de nombre o de lugar basta con cambiar la redirección — los volantes ya
impresos siguen funcionando.

La redirección es **temporal (307), no permanente**, a propósito: una permanente se queda
guardada en el navegador de la gente y ya no habría forma de corregirla.

---

## 2. Neon — la base de datos

1. Crear un proyecto nuevo llamado `agua-segura`.
2. Copiar la **cadena de conexión**. Tiene que ser la que dice **`-pooler`** en el
   servidor; la directa no conecta desde Render.
3. Guardarla para el paso 3. **No pegarla en el chat.**

---

## 3. Render — el servidor

1. **New → Blueprint**, elegir el repositorio `agua-segura`. Lee `render.yaml` solo.
2. Cuando pida las variables:
   - `DATABASE_URL` → la cadena de Neon (la del `-pooler`).
   - `LICENSE_ADMIN_SECRET` → una frase que Toño recuerde; sirve para generar las claves
     de activación de los clientes.
   - `JWT_SECRET` se genera solo.
3. Al desplegar corre las migraciones y queda en:
   `https://aguasegura-api.onrender.com`
4. Comprobarlo abriendo `https://aguasegura-api.onrender.com/health` — debe decir
   `{"status":"ok"}`.

> La capa gratuita de Render **duerme el servidor** tras 15 minutos sin uso. La primera
> carga del día tarda ~30 segundos. La app móvil no se ve afectada porque funciona sin
> internet y sincroniza después.

---

## 4. Vercel — el panel web y la landing

1. **Add New → Project**, importar `agua-segura`.
2. **Root Directory: `web`** ← es el paso que se olvida y hace fallar el build.
3. Framework: Vite. Lo demás por defecto.
4. Desplegar. Queda en `https://agua-segura.vercel.app`.

> Si se cambia el Root Directory después del primer intento, Vercel **no** vuelve a
> desplegar solo: hay que empujar un commit o darle *Redeploy* a mano.

### Enlazar los dominios

Cuando Vercel dé la dirección definitiva, hay que revisar dos cosas:

- En **Render → Environment → `CORS_ORIGINS`**: que incluya el dominio de Vercel. Sin
  eso el panel no puede hablar con el servidor.
- En `web/src/features/landing/LandingPage.tsx` y `web/index.html`: que el enlace del
  APK y las direcciones de las tarjetas de WhatsApp apunten al repositorio y dominio
  reales.

---

## 5. Comprobar que quedó bien

1. Abrir `https://agua-segura.vercel.app/inicio` — debe verse la landing.
2. Crear una cuenta de prueba y dar de alta un cliente.
3. Descargar el APK desde el QR, instalarlo y entrar con la misma cuenta.
4. Registrar un servicio en el celular, sincronizar, y ver que aparece en el panel.

---

## Recomendación pendiente (no urgente)

Hoy el servidor se conecta a Neon con un rol de privilegios elevados que **ignora** las
políticas de aislamiento de la base. El aislamiento entre empresas está garantizado por
el código —y hay pruebas que lo verifican precisamente en ese escenario—, pero conviene
crear en Neon un rol de aplicación sin privilegios especiales para que la base sea un
segundo candado real.

Es lo que ya se documentó para las otras apps. Se hace en 10 minutos cuando haya tiempo.
