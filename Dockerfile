# Multi-stage Dockerfile for Next.js app
# - deps: installs node_modules via npm ci
# - builder: builds the Next.js app
# - runner: minimal runtime image running as non-root

FROM node:20-alpine AS deps
WORKDIR /app

# Some npm packages expect glibc compatibility
RUN apk add --no-cache libc6-compat

COPY package.json package-lock.json* ./
RUN npm ci


FROM node:20-alpine AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# Collect optional Next.js config files (if present) into a known directory
RUN mkdir -p /app/_next_config && \
    sh -c 'ls -1 next.config.* >/dev/null 2>&1 && cp next.config.* /app/_next_config/ || true'


FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Run as non-root
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

# Copy runtime artifacts
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/_next_config/ ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

USER nextjs
EXPOSE 3000

CMD ["npm", "run", "start"]