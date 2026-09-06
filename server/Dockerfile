FROM node:24-alpine
ENV NODE_ENV=production PORT=8787 HOST=0.0.0.0 DATA_DIR=/data
WORKDIR /app/server
COPY server/package.json ./
COPY server/src ./src
COPY assets/catalog.json /app/assets/catalog.json
RUN mkdir -p /data && chown node:node /data
USER node
EXPOSE 8787
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s CMD node -e "fetch('http://127.0.0.1:8787/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/index.mjs"]
