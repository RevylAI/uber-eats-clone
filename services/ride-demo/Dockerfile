FROM node:24-alpine
ENV NODE_ENV=production PORT=8787 HOST=0.0.0.0 DATA_DIR=/data
WORKDIR /app
COPY package.json server.js ./
EXPOSE 8787
VOLUME ["/data"]
CMD ["node", "server.js"]
