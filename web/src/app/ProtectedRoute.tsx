import { Navigate, Outlet } from "react-router-dom";

import { useAuthStore } from "@/shared/auth/store";

/** Deja pasar solo si hay sesión; si no, redirige al login. */
export function ProtectedRoute() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  return isAuthenticated ? <Outlet /> : <Navigate to="/login" replace />;
}
