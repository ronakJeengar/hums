# Hums Web Platform — Deployment & Production Operations

## 1. Environment Configuration

The web platform reads environment settings from `.env.local` (development) or system environment variables (production).

| Variable | Description | Example / Default |
| :--- | :--- | :--- |
| `INTERNAL_API_URL` | Server-to-server URL for FastAPI backend (Host: `http://127.0.0.1:8001`, Docker: `http://api:8001`) | `http://127.0.0.1:8001` |
| `NEXT_PUBLIC_API_URL` | Public API endpoint for direct client calls (fallback) | `http://127.0.0.1:8001` |
| `NODE_ENV` | Runtime environment mode | `production` |
| `PORT` | Web server listening port | `3000` |


---

## 2. Production Build

To produce an optimized production standalone build:

```bash
cd web
npm run build
```

This runs Next.js compiler, Turbopack optimizations, TypeScript typecheck, and compiles static pages and serverless BFF route handlers.

---

## 3. Starting the Production Server

```bash
cd web
npm run start
```

Runs the production server at `http://localhost:3000`.

---

## 4. Docker Deployment

A multi-stage `Dockerfile` for the Next.js platform:

```dockerfile
# Stage 1: Dependencies
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Stage 2: Build
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NODE_ENV=production
RUN npm run build

# Stage 3: Runner
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["npm", "start"]
```
