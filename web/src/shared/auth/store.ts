import { create } from "zustand";

/**
 * Estado de autenticación.
 * - accessToken: en memoria (vida corta), no se persiste.
 * - refreshToken: se persiste en localStorage para sobrevivir recargas.
 */
const REFRESH_KEY = "aguasegura.refresh_token";

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  setTokens: (access: string, refresh: string) => void;
  clear: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  accessToken: null,
  refreshToken: localStorage.getItem(REFRESH_KEY),
  isAuthenticated: Boolean(localStorage.getItem(REFRESH_KEY)),
  setTokens: (access, refresh) => {
    localStorage.setItem(REFRESH_KEY, refresh);
    set({ accessToken: access, refreshToken: refresh, isAuthenticated: true });
  },
  clear: () => {
    localStorage.removeItem(REFRESH_KEY);
    set({ accessToken: null, refreshToken: null, isAuthenticated: false });
  },
}));
