import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const example = new URL('../server/.env.example', import.meta.url);
const destination = new URL('../server/.env', import.meta.url);
if (!existsSync(destination)) {
  const contents = readFileSync(example, 'utf8').replace('replace-with-a-long-random-private-code', randomBytes(24).toString('base64url'));
  writeFileSync(destination, contents, { mode: 0o600 });
  console.log('Se creó server/.env con un código privado. Añade GROQ_API_KEY para activar la IA.');
} else {
  console.log('server/.env ya existe; se conservó su configuración.');
}
console.log('Inicia el servidor con: cd server && npm start');
