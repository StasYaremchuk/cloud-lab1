FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

COPY server.js swagger.json ./

RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 3000

CMD ["node", "server.js"]