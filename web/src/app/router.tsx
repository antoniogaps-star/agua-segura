import { createBrowserRouter } from "react-router-dom";

import { LoginPage } from "@/features/auth/LoginPage";
import { RegisterPage } from "@/features/auth/RegisterPage";
import { ClientsPage } from "@/features/clients/ClientsPage";
import { DashboardPage } from "@/features/dashboard/DashboardPage";
import { LandingPage } from "@/features/landing/LandingPage";
import { ServicesPage } from "@/features/services/ServicesPage";
import { UsersPage } from "@/features/users/UsersPage";

import { AppLayout } from "./AppLayout";
import { ProtectedRoute } from "./ProtectedRoute";

export const router = createBrowserRouter([
  { path: "/inicio", element: <LandingPage /> },
  { path: "/login", element: <LoginPage /> },
  { path: "/register", element: <RegisterPage /> },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <AppLayout />,
        children: [
          { path: "/", element: <DashboardPage /> },
          { path: "/clientes", element: <ClientsPage /> },
          { path: "/servicios", element: <ServicesPage /> },
          { path: "/usuarios", element: <UsersPage /> },
        ],
      },
    ],
  },
]);
