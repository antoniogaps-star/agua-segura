import { create } from "zustand";

/**
 * Aviso global de suscripción vencida. Lo dispara el interceptor de la API cuando el
 * backend responde 402 SUBSCRIPTION_EXPIRED (cuenta en modo solo-lectura), y el layout
 * lo muestra como banner en todas las páginas. Así ninguna pantalla tiene que manejar el
 * 402 por su cuenta.
 */
interface SubscriptionState {
  message: string | null;
  setExpired: (message: string) => void;
  clear: () => void;
}

export const useSubscriptionStore = create<SubscriptionState>((set) => ({
  message: null,
  setExpired: (message) => set({ message }),
  clear: () => set({ message: null }),
}));
