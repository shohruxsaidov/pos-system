FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY src/ ./src/
ARG PORT=3001
EXPOSE $PORT
CMD ["node", "src/server.js"]
