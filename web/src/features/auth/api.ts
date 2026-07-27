import { z } from "zod";

import { api } from "@/shared/api/client";

export const tokenSchema = z.object({
  access_token: z.string(),
  refresh_token: z.string(),
  token_type: z.string(),
});
export type TokenResponse = z.infer<typeof tokenSchema>;

export interface LoginInput {
  company_slug: string;
  email: string;
  password: string;
}

export interface RegisterInput extends LoginInput {
  company_name: string;
}

export async function login(input: LoginInput): Promise<TokenResponse> {
  const { data } = await api.post("/auth/login", input);
  return tokenSchema.parse(data);
}

export async function register(input: RegisterInput): Promise<TokenResponse> {
  const { data } = await api.post("/auth/register", input);
  return tokenSchema.parse(data);
}

export async function logout(refreshToken: string): Promise<void> {
  await api.post("/auth/logout", { refresh_token: refreshToken });
}
