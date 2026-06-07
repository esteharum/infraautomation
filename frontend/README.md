# Frontend — React 18 + Vite + Tailwind CSS

User Management single-page application for LKS 2026.

## Tech stack

| Tool | Purpose |
|---|---|
| React 18 | UI framework |
| Vite 4 | Build tool & dev server |
| Tailwind CSS 3 | Utility-first styling |
| Nginx Alpine | Production static file server |

## Local development (without Docker)

```bash
cd frontend
cp .env.example .env        # Fill in VITE_API_URL
npm install
npm run dev                 # http://localhost:3000
```

The Vite dev server proxies `/api` requests to `http://localhost:8080`
automatically, so you can run the API service separately and both will work
without CORS issues.

## Local development (with Docker Compose)

From the project root:

```bash
docker compose up -d        # starts postgres + api + analytics + frontend
open http://localhost:3000
```

## Production build

```bash
npm run build               # outputs to dist/
```

In production the `dist/` folder is served by Nginx inside the Docker container.
Nginx routes all unknown paths back to `index.html` so React Router works on
hard refresh.

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `VITE_API_URL` | Yes (prod) | Full ALB URL, e.g. `http://lks-alb-xxx.us-east-1.elb.amazonaws.com` |
| `VITE_GRAFANA_URL` | No | Grafana private IP (only reachable from inside lks-monitoring-vpc) |

Leave `VITE_API_URL` empty in `docker-compose.yml` — the Nginx config uses
relative paths, which is correct when frontend and API sit behind the same ALB.

## Component overview

```
App.jsx
├── Navbar.jsx          Top navigation bar
├── MetricsBar.jsx      Live system health strip (polls /api/stats/summary every 30s)
├── UserList.jsx        Data table with search, Edit and Delete per row
└── UserForm.jsx        Controlled form — handles both Create (POST) and Update (PUT)
```

## ALB routing reminder

| Request path | Served by |
|---|---|
| `/*` | This frontend container (port 3000) |
| `/api/*` | API service (port 8080) |
| `/api/stats/*` | Analytics service (port 5000) |
