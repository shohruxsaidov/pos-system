FROM node:22-alpine
WORKDIR /app
RUN npm install -g pnpm
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile
COPY src/ ./src/
ARG PORT=3001
EXPOSE $PORT
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:${PORT:-3001}/health || exit 1
CMD ["node", "src/server.js"]
