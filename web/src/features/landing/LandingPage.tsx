import { Link } from "react-router-dom";

/** Enlace estable a la última versión del APK (el workflow lo sube con nombre fijo). */
const APK_URL =
  "https://github.com/antoniogaps-star/agua-segura/releases/latest/download/agua-segura.apk";

/** La app descargable es solo Android; iPhone/computadora usan el panel web. */
const isIOS =
  typeof navigator !== "undefined" && /iPad|iPhone|iPod/.test(navigator.userAgent);

const MARINO = "#011829";
const AZUL = "#1C74D9";
const AZUL_CLARO = "#5EB2FF";

/**
 * Página pública de venta. Se comparte con otros negocios del mismo giro (lavado de
 * tinacos y mantenimiento) para su prueba gratis.
 *
 * El gancho es el problema real, no la lista de funciones: "se me olvida a quién le
 * toca" es lo que hace que un cliente no vuelva a llamar, y eso es dinero que se va.
 */
export function LandingPage() {
  return (
    <div className="landing">
      <header className="landing-hero" style={{ background: MARINO, color: "#fff" }}>
        <img
          src="/logo-agua-segura.png"
          alt="Agua Segura"
          style={{ width: "min(280px, 64vw)", height: "auto", margin: "0 auto 0.5rem" }}
        />
        <p className="landing-slogan" style={{ color: AZUL_CLARO, marginTop: 0 }}>
          Hogar protegido, agua segura
        </p>
        <p className="landing-lead" style={{ color: "#cbd5e1" }}>
          <strong>Deja de perder clientes por olvido.</strong> La app te dice cada mañana a
          quién le toca su lavado de tinaco, con el mensaje de WhatsApp ya escrito. Tú solo
          le das enviar.
        </p>

        {isIOS && (
          <p
            style={{
              background: "#0a2d4e",
              color: "#fde68a",
              borderRadius: "10px",
              padding: "0.6rem 0.9rem",
              maxWidth: "480px",
              margin: "0.25rem auto 0",
              fontSize: "0.9rem",
            }}
          >
            🍎 En iPhone, Agua Segura se usa en el navegador (la app descargable es para
            Android).
          </p>
        )}

        <div className="landing-cta" style={{ flexWrap: "wrap", gap: "0.6rem" }}>
          <a
            href={APK_URL}
            className="landing-btn"
            style={{
              background: isIOS ? "#334155" : AZUL_CLARO,
              color: isIOS ? "#e2e8f0" : MARINO,
              fontWeight: 700,
              display: "inline-flex",
              alignItems: "center",
              gap: "0.5rem",
              order: isIOS ? 2 : 1,
            }}
          >
            📲 Descargar la app (Android)
          </a>
          <Link
            to="/register"
            className="landing-btn"
            style={{
              background: isIOS ? AZUL_CLARO : AZUL,
              color: isIOS ? MARINO : "#fff",
              fontWeight: 700,
              order: isIOS ? 1 : 2,
            }}
          >
            🍎💻 Usar en el navegador (iPhone/PC)
          </Link>
        </div>
        <p className="landing-note" style={{ color: "#94a3b8" }}>
          Prueba <strong>7 días gratis</strong>, sin tarjeta. En Android, al abrir la app
          toca <strong>"Crear cuenta"</strong> (si lo pide, permite instalar de orígenes
          desconocidos). En iPhone o computadora, crea tu cuenta en el navegador.
        </p>

        <div
          style={{
            display: "inline-flex",
            flexDirection: "column",
            alignItems: "center",
            gap: "0.4rem",
            background: "#fff",
            borderRadius: "16px",
            padding: "12px 12px 8px",
            marginTop: "0.5rem",
          }}
        >
          <img
            src="/qr-app.png"
            alt="Código QR para descargar Agua Segura"
            style={{ width: "160px", height: "160px", display: "block" }}
          />
          <span style={{ color: MARINO, fontSize: "0.85rem", fontWeight: 600 }}>
            📷 Escanea para descargar (Android)
          </span>
        </div>
      </header>

      <section className="landing-features">
        <article className="landing-feature">
          <span className="landing-emoji">🔔</span>
          <h3>¿A quién le toca?</h3>
          <p>
            Cada tinaco se lava cada 6 meses. La app lleva la cuenta sola y te avisa antes
            de que el cliente se olvide de ti.
          </p>
        </article>
        <article className="landing-feature">
          <span className="landing-emoji">📸</span>
          <h3>El certificado que se ve</h3>
          <p>
            Foto del antes y el después, y el comprobante por WhatsApp. Es lo que te abre
            las puertas de restaurantes, escuelas y guarderías.
          </p>
        </article>
        <article className="landing-feature">
          <span className="landing-emoji">🙌</span>
          <h3>Más recomendaciones</h3>
          <p>
            Al terminar, te ayuda a pedirle al cliente que te recomiende — justo cuando
            acaba de ver su tinaco limpio.
          </p>
        </article>
        <article className="landing-feature">
          <span className="landing-emoji">✈️</span>
          <h3>Funciona en la azotea</h3>
          <p>
            Sin señal también. Tu técnico registra todo arriba y sube solo cuando vuelve a
            haber internet.
          </p>
        </article>
        <article className="landing-feature">
          <span className="landing-emoji">💵</span>
          <h3>Tu corte de caja</h3>
          <p>
            Cuánto se cobró hoy, cuánto falta por cobrar y quién quedó a deber. Todo en
            efectivo, sin complicaciones.
          </p>
        </article>
        <article className="landing-feature">
          <span className="landing-emoji">👷</span>
          <h3>Tus técnicos, organizados</h3>
          <p>
            Cada uno ve su agenda del día con la dirección y las referencias para llegar.
          </p>
        </article>
      </section>

      <section className="landing-steps">
        <h2>Así de fácil</h2>
        <ol>
          <li>
            <strong>Registras</strong> el servicio al terminarlo.
          </li>
          <li>
            <strong>La app anota</strong> sola cuándo toca el siguiente.
          </li>
          <li>
            <strong>Te avisa</strong> a los 6 meses y le mandas su WhatsApp.
          </li>
        </ol>
      </section>

      <footer className="landing-foot">
        <a
          href={APK_URL}
          className="landing-btn"
          style={{ background: AZUL_CLARO, color: MARINO, fontWeight: 700 }}
        >
          📲 Descargar (Android)
        </a>
        <Link
          to="/register"
          className="landing-btn"
          style={{
            background: AZUL,
            color: "#fff",
            fontWeight: 700,
            marginLeft: "0.5rem",
          }}
        >
          🍎💻 En el navegador
        </Link>
        <p>Agua Segura · Hogar protegido, agua segura</p>
      </footer>
    </div>
  );
}
