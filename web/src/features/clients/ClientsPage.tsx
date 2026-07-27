import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { abrirWhatsApp } from "@/shared/formato";

import {
  createClient,
  deleteClient,
  fetchClients,
  updateClient,
  type Client,
  type ClientInput,
} from "./api";

const VACIO: ClientInput = {
  name: "",
  phone: "",
  address: "",
  directions: "",
  notes: "",
  referred_by_id: null,
};

/**
 * La cartera de clientes: el activo del negocio. Cada uno costó una recomendación,
 * así que se guarda también QUIÉN lo trajo y cómo llegar a su casa.
 */
export function ClientsPage() {
  const qc = useQueryClient();
  const clientes = useQuery({ queryKey: ["clients"], queryFn: fetchClients });
  const [form, setForm] = useState<ClientInput>(VACIO);
  const [editando, setEditando] = useState<Client | null>(null);

  function refrescar() {
    void qc.invalidateQueries({ queryKey: ["clients"] });
    void qc.invalidateQueries({ queryKey: ["recomendadores"] });
  }

  const guardar = useMutation({
    mutationFn: (input: ClientInput) =>
      editando ? updateClient(editando.id, input) : createClient(input),
    onSuccess: () => {
      setForm(VACIO);
      setEditando(null);
      refrescar();
    },
  });

  const borrar = useMutation({ mutationFn: deleteClient, onSuccess: refrescar });

  const nombrePor = (id: string | null) =>
    id ? (clientes.data?.find((c) => c.id === id)?.name ?? "—") : "—";

  return (
    <div className="page">
      <h1>Clientes</h1>

      <section className="card">
        <h2>{editando ? `Editar: ${editando.name}` : "Nuevo cliente"}</h2>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (!form.name.trim()) return;
            guardar.mutate(form);
          }}
        >
          <label>
            Nombre
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
            />
          </label>
          <label>
            WhatsApp
            <input
              value={form.phone ?? ""}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              placeholder="Por aquí sale el recordatorio y el certificado"
            />
          </label>
          <label>
            Dirección
            <input
              value={form.address ?? ""}
              onChange={(e) => setForm({ ...form, address: e.target.value })}
            />
          </label>
          <label>
            Cómo llegar
            <input
              value={form.directions ?? ""}
              onChange={(e) => setForm({ ...form, directions: e.target.value })}
              placeholder="Portón verde, junto a la tienda"
            />
          </label>
          <label>
            ¿Quién lo recomendó?
            <select
              value={form.referred_by_id ?? ""}
              onChange={(e) =>
                setForm({ ...form, referred_by_id: e.target.value || null })
              }
            >
              <option value="">Nadie / llegó solo</option>
              {clientes.data
                ?.filter((c) => c.id !== editando?.id)
                .map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
            </select>
          </label>
          <label>
            Notas
            <input
              value={form.notes ?? ""}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
            />
          </label>
          <button type="submit" disabled={guardar.isPending}>
            {editando ? "Guardar cambios" : "Agregar cliente"}
          </button>{" "}
          {editando && (
            <button
              type="button"
              className="secondary"
              onClick={() => {
                setEditando(null);
                setForm(VACIO);
              }}
            >
              Cancelar
            </button>
          )}
          {guardar.isError && <p className="error">No se pudo guardar.</p>}
        </form>
      </section>

      <section className="card">
        <h2>Tu cartera ({clientes.data?.length ?? 0})</h2>
        {clientes.isPending && <p>Cargando…</p>}
        <table>
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Dirección y referencias</th>
              <th>Lo recomendó</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {clientes.data?.map((c) => (
              <tr key={c.id}>
                <td>{c.name}</td>
                <td>
                  {c.address ?? "—"}
                  {c.directions && (
                    <div style={{ color: "#666", fontStyle: "italic" }}>{c.directions}</div>
                  )}
                </td>
                <td>{nombrePor(c.referred_by_id)}</td>
                <td style={{ whiteSpace: "nowrap" }}>
                  {c.phone && (
                    <>
                      <button
                        type="button"
                        className="linkbtn"
                        onClick={() =>
                          abrirWhatsApp(
                            c.phone,
                            `Hola ${c.name}, le escribimos de Agua Segura.`,
                          )
                        }
                      >
                        WhatsApp
                      </button>{" "}
                    </>
                  )}
                  <button
                    type="button"
                    className="linkbtn"
                    onClick={() => {
                      setEditando(c);
                      setForm({
                        name: c.name,
                        phone: c.phone ?? "",
                        address: c.address ?? "",
                        directions: c.directions ?? "",
                        notes: c.notes ?? "",
                        referred_by_id: c.referred_by_id,
                      });
                    }}
                  >
                    Editar
                  </button>{" "}
                  <button
                    type="button"
                    className="linkbtn"
                    onClick={() => {
                      if (confirm(`¿Quitar a ${c.name} de tu cartera?`)) borrar.mutate(c.id);
                    }}
                  >
                    Quitar
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
