import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { fetchClients, fetchRecomendadores } from "@/features/clients/api";
import { createJob, fetchPendientes, TIPOS } from "@/features/services/api";
import { abrirWhatsApp, enPalabras, fechaLarga } from "@/shared/formato";

import { fetchMe } from "./api";

/// Cada cuántos meses toca cada servicio (para redactar el recordatorio).
const MESES: Record<string, number> = {
  tinacos: 6,
  techos: 12,
  calentadores: 12,
  impermeabilizacion: 24,
};

function mensajeRecordatorio(nombre: string, tipo: string, ultima: string | null): string {
  const servicio = (TIPOS[tipo] ?? tipo).toLowerCase();
  const meses = MESES[tipo] ?? 6;
  const cuando = ultima ? ` (última vez: ${fechaLarga(ultima)})` : "";
  return (
    `Buen día, ${nombre}. Le escribimos de Agua Segura. ` +
    `Ya se cumplieron ${meses} meses de su servicio de ${servicio}${cuando}. ` +
    `¿Le agendamos su servicio esta semana?`
  );
}

/// Rojo = ya se pasó · Ámbar = esta semana · Verde = este mes.
function color(dias: number): string {
  if (dias >= 0) return "#dc2626";
  if (dias >= -7) return "#b45309";
  return "#15803d";
}

/**
 * Inicio del panel. Lo primero que se ve es **¿A quién le toca?**, igual que en el
 * celular: es el problema que originó la app, no un reporte más.
 */
export function DashboardPage() {
  const qc = useQueryClient();
  const me = useQuery({ queryKey: ["me"], queryFn: fetchMe });
  const clientes = useQuery({ queryKey: ["clients"], queryFn: fetchClients });
  const pendientes = useQuery({ queryKey: ["pendientes"], queryFn: fetchPendientes });
  const recomendadores = useQuery({
    queryKey: ["recomendadores"],
    queryFn: fetchRecomendadores,
  });

  const agendar = useMutation({
    mutationFn: (p: { client_id: string; service_type: string; scheduled_for: string }) =>
      createJob(p),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["pendientes"] });
      void qc.invalidateQueries({ queryKey: ["services"] });
    },
  });

  const lista = pendientes.data ?? [];
  const vencidos = lista.filter((p) => p.days_overdue >= 0);

  return (
    <div className="page">
      <h1>¿A quién le toca?</h1>
      <p style={{ color: "#666", marginTop: "-0.5rem" }}>
        Bienvenido{me.data ? `, ${me.data.email}` : ""}. 💧
      </p>

      <div className="stat-grid" style={{ marginBottom: "1.5rem" }}>
        <div className="stat">
          <div className="value" style={{ color: "#dc2626" }}>
            {pendientes.isPending ? "—" : vencidos.length}
          </div>
          <div className="label">Ya vencidos</div>
        </div>
        <div className="stat">
          <div className="value">
            {pendientes.isPending ? "—" : lista.length - vencidos.length}
          </div>
          <div className="label">Por vencer este mes</div>
        </div>
        <div className="stat">
          <div className="value">{clientes.data?.length ?? "—"}</div>
          <div className="label">Clientes</div>
        </div>
      </div>

      <section className="card">
        <h2>Les toca su mantenimiento</h2>
        {pendientes.isPending && <p>Cargando…</p>}
        {!pendientes.isPending && lista.length === 0 && (
          <p style={{ color: "#666" }}>
            Nadie pendiente: todos están al día o ya tienen su visita agendada.
          </p>
        )}
        {lista.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Cliente</th>
                <th>Servicio</th>
                <th>Situación</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {lista.map((p) => (
                <tr key={`${p.client_id}-${p.service_type}`}>
                  <td>{p.client_name}</td>
                  <td>{TIPOS[p.service_type] ?? p.service_type}</td>
                  <td style={{ color: color(p.days_overdue), fontWeight: 600 }}>
                    {enPalabras(p.days_overdue)}
                  </td>
                  <td style={{ whiteSpace: "nowrap" }}>
                    <button
                      type="button"
                      className="linkbtn"
                      onClick={() => {
                        const ok = abrirWhatsApp(
                          p.client_phone,
                          mensajeRecordatorio(
                            p.client_name,
                            p.service_type,
                            p.last_service_on,
                          ),
                        );
                        if (!ok) alert("Ese cliente no tiene teléfono guardado.");
                      }}
                    >
                      WhatsApp
                    </button>{" "}
                    <button
                      type="button"
                      className="linkbtn"
                      disabled={agendar.isPending}
                      onClick={() => {
                        const cuando = prompt(
                          "¿Qué día se agenda? (año-mes-día, por ejemplo 2026-08-15)",
                          new Date().toISOString().slice(0, 10),
                        );
                        if (!cuando) return;
                        agendar.mutate({
                          client_id: p.client_id,
                          service_type: p.service_type,
                          scheduled_for: `${cuando}T09:00:00`,
                        });
                      }}
                    >
                      Agendar
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      {(recomendadores.data?.length ?? 0) > 0 && (
        <section className="card">
          <h2>Quién te trae clientes</h2>
          <p style={{ color: "#666", marginTop: "-0.5rem" }}>
            Llegaron por recomendación. A estos conviene agradecerles — y volver a
            pedirles.
          </p>
          <table>
            <thead>
              <tr>
                <th>Cliente</th>
                <th>Ha recomendado</th>
              </tr>
            </thead>
            <tbody>
              {recomendadores.data?.map((r) => (
                <tr key={r.client_id}>
                  <td>{r.name}</td>
                  <td>{r.recomendados}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </div>
  );
}
