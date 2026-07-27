import { useQuery } from "@tanstack/react-query";

import { fetchMe } from "@/features/dashboard/api";

const ROLES: Record<string, string> = {
  owner: "Dueño",
  admin: "Administrador",
  seller: "Vendedor",
};

export function UsersPage() {
  const me = useQuery({ queryKey: ["me"], queryFn: fetchMe });

  return (
    <div className="page">
      <h1>Usuarios y permisos</h1>
      <p style={{ color: "#666", marginTop: "-0.5rem" }}>
        Personas con acceso a tu negocio y su rol.
      </p>

      <section className="card">
        <table>
          <thead>
            <tr>
              <th>Correo</th>
              <th>Rol</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            {me.data && (
              <tr>
                <td>{me.data.email}</td>
                <td>{ROLES[me.data.role] ?? me.data.role}</td>
                <td>{me.data.is_active ? "Activo" : "Inactivo"}</td>
              </tr>
            )}
          </tbody>
        </table>
      </section>

      <section className="card">
        <h2>Agregar usuarios</h2>
        <p>
          Invitar vendedores o administradores con permisos por rol estará disponible aquí.
        </p>
        <p style={{ color: "#666" }}>
          Los planes <strong>Profesional</strong> y <strong>Empresarial</strong> incluyen
          usuarios y permisos.
        </p>
      </section>
    </div>
  );
}
