import { z } from "zod";

import { api } from "@/shared/api/client";

/// Los cinco servicios del negocio, con su nombre para pantalla.
export const TIPOS: Record<string, string> = {
  tinacos: "Lavado y desinfección de tinacos",
  techos: "Mantenimiento de techos",
  plomeria: "Plomería",
  impermeabilizacion: "Impermeabilización",
  calentadores: "Calentadores solares",
};

export const serviceJobSchema = z.object({
  id: z.string(),
  client_id: z.string(),
  service_type: z.string(),
  status: z.string(),
  scheduled_for: z.string().nullable(),
  performed_on: z.string().nullable(),
  technician_id: z.string().nullable(),
  price_cents: z.number(),
  is_paid: z.boolean(),
  notes: z.string().nullable(),
  next_due_on: z.string().nullable(),
});
export type ServiceJob = z.infer<typeof serviceJobSchema>;

/// Un cliente al que ya le tocó su mantenimiento, o le toca pronto.
export const pendienteSchema = z.object({
  client_id: z.string(),
  client_name: z.string(),
  client_phone: z.string().nullable(),
  service_type: z.string(),
  last_service_on: z.string().nullable(),
  due_on: z.string(),
  // Positivo = ya se pasó · Negativo = todavía faltan días.
  days_overdue: z.number(),
});
export type Pendiente = z.infer<typeof pendienteSchema>;

export async function fetchJobs(status?: string): Promise<ServiceJob[]> {
  const { data } = await api.get("/services", { params: status ? { status } : {} });
  return z.array(serviceJobSchema).parse(data);
}

export async function fetchPendientes(): Promise<Pendiente[]> {
  const { data } = await api.get("/services/pendientes");
  return z.array(pendienteSchema).parse(data);
}

export async function createJob(input: {
  client_id: string;
  service_type: string;
  scheduled_for?: string | null;
  notes?: string | null;
}): Promise<ServiceJob> {
  const { data } = await api.post("/services", input);
  return serviceJobSchema.parse(data);
}

export async function completeJob(
  id: string,
  input: { price_cents?: number; is_paid?: boolean; performed_on?: string },
): Promise<ServiceJob> {
  const { data } = await api.post(`/services/${id}/complete`, input);
  return serviceJobSchema.parse(data);
}
