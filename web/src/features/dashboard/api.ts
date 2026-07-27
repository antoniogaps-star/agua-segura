import { z } from "zod";

import { api } from "@/shared/api/client";

export const userSchema = z.object({
  id: z.string(),
  tenant_id: z.string(),
  email: z.string(),
  role: z.string(),
  is_active: z.boolean(),
});
export type User = z.infer<typeof userSchema>;

export async function fetchMe(): Promise<User> {
  const { data } = await api.get("/users/me");
  return userSchema.parse(data);
}
