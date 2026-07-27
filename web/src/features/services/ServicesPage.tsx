import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { fetchClients } from "@/features/clients/api";
import { fechaCorta, pesos } from "@/shared/formato";

import { completeJob, createJob, fetchJobs, TIPOS } from "./api";

/// Precio sugerido en centavos. El de tinacos es fijo; lo demás se cotiza cada vez.
const SUGERIDO: Record<string, number> = { tinacos: 70000 };

/**
 * Servicios: lo agendado y lo ya realizado, con el corte de caja arriba.
 *
 * Todo el negocio es en efectivo, así que la caja son dos números —cobrado y por
 * cobrar— y la lista de quién quedó a deber.
 */
export function ServicesPage() {
  const qc = useQueryClient();
  const trabajos = useQuery({ queryKey: ["services"], queryFn: () => fetchJobs() });
  const clientes = useQuery({ queryKey: ["clients"], queryFn: fetchClients });
  const [clienteId, setClienteId] = useState("");
  const [tipo, setTipo] = useState("tinacos");
  const [cuando, setCuando] = useState(new Date().toISOString().slice(0, 10));

  function refrescar() {
    void qc.invalidateQueries({ queryKey: ["services"] });
    void qc.invalidateQueries({ queryKey: ["pendientes"] });
  }

  const agendar = useMutation({
    mutationFn: () =>
      createJob({
        client_id: clienteId,
        service_type: tipo,
        scheduled_for: `${cuando}T09:00:00`,
      }),
    onSuccess: () => {
      setClienteId("");
      refrescar();
    },
  });

  const terminar = useMutation({
    mutationFn: (p: { id: string; price_cents: number; is_paid: boolean }) =>
      completeJob(p.id, { price_cents: p.price_cents, is_paid: p.is_paid }),
    onSuccess: refrescar,
  });

  const cobrar = useMutation({
    mutationFn: (p: { id: string; price_cents: number }) =>
      completeJob(p.id, { price_cents: p.price_cents, is_paid: true }),
    onSuccess: refrescar,
  });

  const lista = trabajos.data ?? [];
  const agendados = lista.filter((j) => j.status === "agendado");
  const realizados = lista.filter((j) => j.status === "realizado");
  const cobrado = realizados.filter((j) => j.is_paid).reduce((s, j) => s + j.price_cents, 0);
  const porCobrar = realizados
    .filter((j) => !j.is_paid)
    .reduce((s, j) => s + j.price_cents, 0);

  const nombre = (id: string) =>
    clientes.data?.find((c) => c.id === id)?.name ?? "Cliente";

  return (
    <div className="page">
      <h1>Servicios y caja</h1>

      <div className="stat-grid" style={{ marginBottom: "1.5rem" }}>
        <div className="stat">
          <div className="value" style={{ color: "#15803d" }}>
            {pesos(cobrado)}
          </div>
          <div className="label">Cobrado</div>
        </div>
        <div className="stat">
          <div className="value" style={{ color: "#b45309" }}>
            {pesos(porCobrar)}
          </div>
          <div className="label">Por cobrar</div>
        </div>
        <div className="stat">
          <div className="value">{agendados.length}</div>
          <div className="label">Visitas agendadas</div>
        </div>
      </div>

      <section className="card">
        <h2>Agendar una visita</h2>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (!clienteId) return;
            agendar.mutate();
          }}
        >
          <label>
            Cliente
            <select value={clienteId} onChange={(e) => setClienteId(e.target.value)} required>
              <option value="">Elige un cliente…</option>
              {clientes.data?.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Servicio
            <select value={tipo} onChange={(e) => setTipo(e.target.value)}>
              {Object.entries(TIPOS).map(([clave, texto]) => (
                <option key={clave} value={clave}>
                  {texto}
                </option>
              ))}
            </select>
          </label>
          <label>
            Fecha
            <input type="date" value={cuando} onChange={(e) => setCuando(e.target.value)} />
          </label>
          <button type="submit" disabled={agendar.isPending}>
            Agendar
          </button>
          {agendar.isError && <p className="error">No se pudo agendar.</p>}
        </form>
      </section>

      <section className="card">
        <h2>Agendadas ({agendados.length})</h2>
        {agendados.length === 0 && <p style={{ color: "#666" }}>Nada agendado.</p>}
        {agendados.length > 0 && (
          <table>
            <thead>
              <tr>
                <th>Cliente</th>
                <th>Servicio</th>
                <th>Fecha</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {agendados.map((j) => (
                <tr key={j.id}>
                  <td>{nombre(j.client_id)}</td>
                  <td>{TIPOS[j.service_type] ?? j.service_type}</td>
                  <td>{j.scheduled_for ? fechaCorta(j.scheduled_for) : "—"}</td>
                  <td style={{ whiteSpace: "nowrap" }}>
                    <button
                      type="button"
                      className="linkbtn"
                      disabled={terminar.isPending}
                      onClick={() => {
                        const sugerido = j.price_cents || SUGERIDO[j.service_type] || 0;
                        const texto = prompt(
                          "¿Cuánto se cobró? (en pesos)",
                          (sugerido / 100).toFixed(2),
                        );
                        if (texto === null) return;
                        const centavos = Math.round(Number(texto.replace(/[^0-9.]/g, "")) * 100);
                        terminar.mutate({
                          id: j.id,
                          price_cents: centavos,
                          is_paid: confirm("¿Ya te pagó?"),
                        });
                      }}
                    >
                      Marcar realizada
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="card">
        <h2>Realizadas ({realizados.length})</h2>
        <table>
          <thead>
            <tr>
              <th>Cliente</th>
              <th>Servicio</th>
              <th>Se hizo</th>
              <th>Cobro</th>
              <th>Próximo</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {realizados.map((j) => (
              <tr key={j.id}>
                <td>{nombre(j.client_id)}</td>
                <td>{TIPOS[j.service_type] ?? j.service_type}</td>
                <td>{j.performed_on ? fechaCorta(j.performed_on) : "—"}</td>
                <td style={{ color: j.is_paid ? "#15803d" : "#b45309" }}>
                  {pesos(j.price_cents)} {j.is_paid ? "" : "(debe)"}
                </td>
                <td>{j.next_due_on ? fechaCorta(j.next_due_on) : "—"}</td>
                <td>
                  {!j.is_paid && (
                    <button
                      type="button"
                      className="linkbtn"
                      disabled={cobrar.isPending}
                      onClick={() => cobrar.mutate({ id: j.id, price_cents: j.price_cents })}
                    >
                      Ya me pagó
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
