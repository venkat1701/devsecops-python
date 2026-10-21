# ---- Stage 1: build the React app with Node ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build

# ---- Stage 2: serve static files with unprivileged Nginx (runs as uid 101, port 8080) ----
FROM nginxinc/nginx-unprivileged:1.29-alpine
# Pick up Alpine security fixes published after the base image was built.
USER root
RUN apk upgrade --no-cache
# Where Nginx proxies /api. Compose uses the `backend` service; Helm sets the release's backend Service.
ENV BACKEND_URL=http://backend:8000
COPY --from=build /app/dist /usr/share/nginx/html
# The image's entrypoint renders templates/*.template -> conf.d/ with envsubst at start-up.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
USER 101
EXPOSE 8080
