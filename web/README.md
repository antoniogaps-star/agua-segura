# Ágora ERP — Panel Web

React + TypeScript + Vite. Herramienta de administración (online-first).

## Requisitos

- Node 20+

## Puesta en marcha

```bash
cd web
npm install
npm run dev      # http://localhost:5173
```

## Estructura

```
src/
├── app/          # entrypoint, router, providers
├── features/     # feature-first (auth, users, tenant-settings, …)
├── shared/       # ui, api client, hooks, types
├── lib/          # queryClient, config
└── styles/
```

## Comandos

```bash
npm run lint
npm run build
npm run test
```

Ver [`docs/08_Panel_Web.md`](../docs/08_Panel_Web.md).
