import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";

import { useAuthStore } from "@/shared/auth/store";
import { slugify } from "@/lib/slug";

import { login } from "./api";

export function LoginPage() {
  const navigate = useNavigate();
  const setTokens = useAuthStore((s) => s.setTokens);
  const [form, setForm] = useState({ company_slug: "", email: "", password: "" });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setLoading(true);
    try {
      // El usuario escribe el NOMBRE; se traduce al identificador igual que en el móvil.
      const tokens = await login({ ...form, company_slug: slugify(form.company_slug) });
      setTokens(tokens.access_token, tokens.refresh_token);
      navigate("/");
    } catch {
      setError("No se pudo entrar. Revisa el nombre de tu negocio, correo y contraseña.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="center">
      <form className="card" onSubmit={onSubmit}>
        <h1>Agua Segura · Entrar</h1>
        <p className="slogan">Hogar protegido, agua segura</p>

        <label htmlFor="company_slug">Tu negocio</label>
        <input
          id="company_slug"
          value={form.company_slug}
          onChange={(e) => setForm({ ...form, company_slug: e.target.value })}
          placeholder="Por ejemplo: Agua Segura"
          required
        />

        <label htmlFor="email">Correo</label>
        <input
          id="email"
          type="email"
          value={form.email}
          onChange={(e) => setForm({ ...form, email: e.target.value })}
          required
        />

        <label htmlFor="password">Contraseña</label>
        <input
          id="password"
          type={showPassword ? "text" : "password"}
          value={form.password}
          onChange={(e) => setForm({ ...form, password: e.target.value })}
          required
        />
        <label style={{ fontWeight: "normal", fontSize: "0.9em", cursor: "pointer" }}>
          <input
            type="checkbox"
            checked={showPassword}
            onChange={(e) => setShowPassword(e.target.checked)}
          />{" "}
          Ver contraseña
        </label>

        {error && <p className="error">{error}</p>}

        <button type="submit" disabled={loading}>
          {loading ? "Entrando…" : "Entrar"}
        </button>
        <Link to="/register">
          <button type="button" className="secondary">
            Crear cuenta
          </button>
        </Link>
      </form>
    </div>
  );
}
