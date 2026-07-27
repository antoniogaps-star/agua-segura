/** Configuración de la app web, leída de variables de entorno de Vite. */

// En producción (Vercel) el backend público es el de Render; en desarrollo, el local.
// VITE_API_URL la puede sobreescribir (p. ej. "" en el build Docker para usar rutas
// relativas detrás de nginx).
const defaultApiUrl = import.meta.env.PROD
  ? "https://aguasegura-api.onrender.com"
  : "http://localhost:8000";

export const config = {
  apiUrl: import.meta.env.VITE_API_URL ?? defaultApiUrl,
  apiPrefix: "/api/v1",
} as const;
