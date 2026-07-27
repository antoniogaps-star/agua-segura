import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";

import { useAuthStore } from "@/shared/auth/store";
import { slugify } from "@/lib/slug";

import { register } from "./api";

export function RegisterPage() {
  const navigate = useNavigate();
  const setTokens = useAuthStore((s) => s.setTokens);
  const [form, setForm] = useState({
    company_name: "",
    email: "",
    password: "",
  });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const tokens = await register({ ...form, company_slug: slugify(form.company_name) });
      setTokens(tokens.access_token, tokens.refresh_token);
      navigate("/");
    } catch {
      setError("No se pudo crear la cuenta (¿ese nombre o correo ya existen?)");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="center">
      <form className="card" onSubmit={onSubmit} autoComplete="off">
        <h1>Agua Segura · Crear cuenta</h1>
        <p className="slogan">Protegemos tu hogar desde lo más alto</p>

        <label htmlFor="company_name">Nombre de tu negocio</label>
        <input
          id="company_name"
          value={form.company_name}
          onChange={(e) => setForm({ ...form, company_name: e.target.value })}
          autoComplete="off"
          required
        />

        <label htmlFor="email">Correo del dueño</label>
        <input
          id="email"
          type="email"
          value={form.email}
          onChange={(e) => setForm({ ...form, email: e.target.value })}
          autoComplete="off"
          required
        />

        <label htmlFor="password">Contraseña</label>
        <input
          id="password"
          type={showPassword ? "text" : "password"}
          value={form.password}
          onChange={(e) => setForm({ ...form, password: e.target.value })}
          autoComplete="new-password"
          minLength={8}
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
          {loading ? "Creando…" : "Crear cuenta"}
        </button>
        <Link to="/login">
          <button type="button" className="secondary">
            Ya tengo cuenta
          </button>
        </Link>
      </form>
    </div>
  );
}
