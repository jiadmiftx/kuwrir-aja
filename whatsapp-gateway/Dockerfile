FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY src ./src

# Auth session persists here — mount a named volume over this path so
# pairing survives redeploys.
RUN mkdir -p /app/auth_session

ENV PORT=3000
EXPOSE 3000

CMD ["node", "src/index.js"]
