import { z } from "zod";

import { api } from "@/shared/api/client";

export const clientSchema = z.object({
  id: z.string(),
  name: z.string(),
  phone: z.string().nullable(),
  address: z.string().nullable(),
  // Cómo llegar: el técnico las usa más que la calle y el número.
  directions: z.string().nullable(),
  notes: z.string().nullable(),
  referred_by_id: z.string().nullable(),
});
export type Client = z.infer<typeof clientSchema>;

export const recomendadorSchema = z.object({
  client_id: z.string(),
  name: z.string(),
  phone: z.string().nullable(),
  recomendados: z.number(),
});
export type Recomendador = z.infer<typeof recomendadorSchema>;

export async function fetchClients(): Promise<Client[]> {
  const { data } = await api.get("/clients");
  return z.array(clientSchema).parse(data);
}

export async function fetchRecomendadores(): Promise<Recomendador[]> {
  const { data } = await api.get("/clients/recomendadores");
  return z.array(recomendadorSchema).parse(data);
}

export type ClientInput = {
  name: string;
  phone?: string | null;
  address?: string | null;
  directions?: string | null;
  notes?: string | null;
  referred_by_id?: string | null;
};

export async function createClient(input: ClientInput): Promise<Client> {
  const { data } = await api.post("/clients", input);
  return clientSchema.parse(data);
}

/// Edición parcial: solo se manda lo que cambió, para no borrar sin querer lo demás.
export async function updateClient(
  id: string,
  cambios: Partial<ClientInput>,
): Promise<Client> {
  const { data } = await api.patch(`/clients/${id}`, cambios);
  return clientSchema.parse(data);
}

export async function deleteClient(id: string): Promise<void> {
  await api.delete(`/clients/${id}`);
}
