import { resolve } from 'node:path';
import { createApp } from './app.mjs';

const config = {
  databasePath: resolve(process.env.DATA_DIR || './data', 'musa.sqlite'),
  pairingCode: process.env.PAIRING_CODE || '',
  groqKey: process.env.GROQ_API_KEY || '',
  geminiKey: process.env.GEMINI_API_KEY || '',
  chatModel: process.env.GROQ_CHAT_MODEL || 'openai/gpt-oss-120b',
  visionModel: process.env.GROQ_VISION_MODEL || 'qwen/qwen3.6-27b',
  imageModel: process.env.GEMINI_IMAGE_MODEL || 'gemini-3.1-flash-image',
  allowedOrigins: (process.env.ALLOWED_ORIGINS || 'http://localhost:8080,http://127.0.0.1:8080').split(',').map(s => s.trim()).filter(Boolean),
  dailyPreviewLimit: Math.max(1, Number(process.env.DAILY_PREVIEW_LIMIT || 10))
};
if (config.pairingCode.length < 12) {
  console.error('Configura PAIRING_CODE con al menos 12 caracteres en server/.env. Ejecuta scripts/setup.mjs.');
  process.exit(1);
}
const { server, store } = createApp(config);
server.listen(Number(process.env.PORT || 8787), process.env.HOST || '0.0.0.0', () => console.log(`Musa API lista en el puerto ${process.env.PORT || 8787}`));
for (const signal of ['SIGTERM', 'SIGINT']) process.once(signal, () => server.close(() => { store.close(); process.exit(0); }));
