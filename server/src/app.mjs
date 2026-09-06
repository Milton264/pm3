import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { AppError, fail, hash, sameSecret, id, string, tags, imageInput, garmentInput, styleProfile, validOutfit, canDress } from './domain.mjs';
import { Store } from './store.mjs';
import { Providers } from './providers.mjs';

const bundledCatalog = JSON.parse(readFileSync(new URL('../../assets/catalog.json', import.meta.url), 'utf8'));
const json = (res, status, value) => { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(value)); };
async function body(req) {
  if (!(req.headers['content-type'] ?? '').startsWith('application/json')) fail(415, 'CONTENT_TYPE', 'Envía los datos como JSON.');
  const chunks = []; let size = 0;
  for await (const chunk of req) { size += chunk.length; if (size > 12 * 1024 * 1024) fail(413, 'TOO_LARGE', 'La solicitud es demasiado grande.'); chunks.push(chunk); }
  try { const result = JSON.parse(Buffer.concat(chunks)); if (!result || typeof result !== 'object' || Array.isArray(result)) throw Error(); return result; }
  catch { fail(400, 'INVALID_JSON', 'La solicitud no se pudo leer.'); }
}
export function createApp(config, { store = new Store(config.databasePath), providers = new Providers(config) } = {}) {
  const catalog = () => [...bundledCatalog, ...store.all('inspiration')];
  const votes = () => store.setting('votes', {});
  const profile = () => store.setting('profile', { name: '', notes: '', bodyPhotoId: null });
  const context = () => ({ wardrobe: store.all('garment').filter(g => g.available), taste: styleProfile(catalog(), votes()), profile: { name: profile().name, notes: profile().notes } });
  const need = (kind, key) => store.get(kind, key) ?? fail(404, 'NOT_FOUND', 'Este elemento ya no está disponible.');
  const aiLimit = () => { if (!store.limit('ai', 25, 60_000)) fail(429, 'RATE_LIMIT', 'Espera un momento antes de hacer otra consulta.'); };
  const saveLook = (candidate, occasion) => store.put('look', { ...validOutfit(candidate, store.all('garment')),
    id: id(), created: Date.now(), saved: false, occasion, previewId: null });
  const removeLook = key => { const l = store.get('look', key); if (!l) return; store.deleteMedia(l.previewId); store.delete('look', key); };
  const once = async (req, fn) => {
    const key = string(req.headers['idempotency-key'], 100, true);
    if (!/^[A-Za-z0-9_-]{12,100}$/.test(key)) fail(400, 'IDEMPOTENCY_KEY', 'Falta un identificador de solicitud válido.');
    const scoped = `${req.url}:${key}`;
    store.db.prepare('DELETE FROM requests WHERE created<?').run(Date.now() - 24 * 60 * 60_000);
    const old = store.db.prepare('SELECT response FROM requests WHERE key=?').get(scoped);
    if (old) { if (old.response) return JSON.parse(old.response); fail(409, 'IN_PROGRESS', 'La solicitud ya se está procesando.'); }
    store.db.prepare('INSERT INTO requests VALUES(?,NULL,?)').run(scoped, Date.now());
    try { const result = await fn(); store.db.prepare('UPDATE requests SET response=? WHERE key=?').run(JSON.stringify(result), scoped); return result; }
    catch (error) { store.db.prepare('DELETE FROM requests WHERE key=?').run(scoped); throw error; }
  };
  let chatBusy = false; const previewBusy = new Set();
  const server = createServer(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    const origin = req.headers.origin;
    if (origin && config.allowedOrigins.includes(origin)) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); }
    try {
      if (origin && !config.allowedOrigins.includes(origin)) fail(403, 'ORIGIN', 'Este origen no está autorizado.');
      if (req.method === 'OPTIONS') {
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization,Idempotency-Key');
        res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
        res.writeHead(204); res.end(); return;
      }
      const path = new URL(req.url, 'http://localhost').pathname;
      if (req.method === 'GET' && path === '/health') { json(res, 200, { status: 'ok', app: 'musa', version: '1.0.0' }); return; }
      if (req.method === 'POST' && path === '/v1/session') {
        const ip = req.socket.remoteAddress ?? 'unknown';
        if (!store.limit(`pair:${ip}`, 8, 15 * 60_000)) fail(429, 'PAIR_LIMIT', 'Demasiados intentos. Espera 15 minutos.');
        const input = await body(req);
        if (!sameSecret(string(input.code, 200, true), config.pairingCode)) fail(401, 'PAIR_CODE', 'El código de acceso no coincide.');
        const token = `${id()}${id()}`;
        store.db.prepare('DELETE FROM sessions WHERE expires<?').run(Date.now());
        store.db.prepare('INSERT INTO sessions VALUES(?,?)').run(hash(token), Date.now() + 90 * 24 * 60 * 60_000);
        json(res, 201, { token }); return;
      }
      const token = req.headers.authorization?.replace(/^Bearer /, '');
      if (!token || !store.db.prepare('SELECT hash FROM sessions WHERE hash=? AND expires>?').get(hash(token), Date.now()))
        fail(401, 'SESSION_EXPIRED', 'Conecta tu espacio para continuar.');
      if (!store.limit(`api:${hash(token)}`, 180, 60_000)) fail(429, 'RATE_LIMIT', 'Espera un momento antes de continuar.');

      if (req.method === 'DELETE' && path === '/v1/session') { store.db.prepare('DELETE FROM sessions WHERE hash=?').run(hash(token)); json(res, 200, { ok: true }); return; }
      if (req.method === 'GET' && path === '/v1/bootstrap') {
        json(res, 200, { profile: profile(), votes: votes(), style: styleProfile(catalog(), votes()),
          garments: store.all('garment'), looks: store.all('look').reverse(), messages: store.all('message').slice(-100),
          inspirations: store.all('inspiration'), capabilities: { groq: !!config.groqKey, preview: !!config.geminiKey } }); return;
      }
      if (req.method === 'GET' && /^\/v1\/media\/[a-f0-9]{32}$/.test(path)) {
        const image = store.media(path.split('/').at(-1));
        if (!image) fail(404, 'NOT_FOUND', 'La fotografía ya no está disponible.');
        res.writeHead(200, { 'Content-Type': image.mime, 'Content-Length': image.bytes.length }); res.end(Buffer.from(image.bytes)); return;
      }
      if (req.method === 'PUT' && path === '/v1/votes') {
        const input = await body(req); const all = new Set(catalog().map(i => i.id));
        if (!input.votes || typeof input.votes !== 'object' || Array.isArray(input.votes) || Object.keys(input.votes).length > 1000)
          fail(400, 'INVALID_VOTES', 'Revisa las selecciones de estilo.');
        const next = { ...votes() };
        for (const [key, value] of Object.entries(input.votes)) {
          if (!all.has(key) || (value !== null && typeof value !== 'boolean')) fail(400, 'INVALID_VOTES', 'Esta referencia no está disponible.');
          if (value === null) delete next[key]; else next[key] = value;
        }
        store.set('votes', next); json(res, 200, { votes: next, style: styleProfile(catalog(), next) }); return;
      }
      if (req.method === 'POST' && path === '/v1/analyze') {
        const input = await body(req); aiLimit();
        const result = await providers.analyze(imageInput(input.image), input.kind === 'inspiration' ? 'inspiration' : 'garment');
        if (input.kind !== 'inspiration') { const parsed = garmentInput(result); json(res, 200, parsed); }
        else json(res, 200, { title: string(result.title, 80, true), tags: tags(result.tags), description: string(result.description ?? '', 500) });
        return;
      }
      if (req.method === 'POST' && path === '/v1/garments') {
        const input = await body(req); const parsed = garmentInput(input); const photo = imageInput(input.image);
        if (store.all('garment').length >= 400) fail(400, 'WARDROBE_FULL', 'El armario admite hasta 400 prendas.');
        const record = store.transaction(() => store.put('garment', { ...parsed, id: id(), created: Date.now(), imageId: store.addMedia(photo) }));
        json(res, 201, record); return;
      }
      if (/^\/v1\/garments\/[a-f0-9]{32}$/.test(path)) {
        const key = path.split('/').at(-1); const old = need('garment', key);
        if (req.method === 'PUT') { const input = await body(req); json(res, 200, store.put('garment', { ...old, ...garmentInput(input) })); return; }
        if (req.method === 'DELETE') {
          store.transaction(() => { for (const look of store.all('look').filter(l => l.garmentIds.includes(key))) removeLook(look.id); store.deleteMedia(old.imageId); store.delete('garment', key); });
          json(res, 200, { ok: true }); return;
        }
      }
      if (req.method === 'POST' && path === '/v1/inspirations') {
        const input = await body(req); const title = string(input.title, 80, true); const styleTags = tags(input.tags);
        const photo = imageInput(input.image);
        if (store.all('inspiration').length >= 500) fail(400, 'CATALOG_FULL', 'Puedes guardar hasta 500 referencias propias.');
        json(res, 201, store.transaction(() => store.put('inspiration', { id: id(), title, tags: styleTags, created: Date.now(), imageId: store.addMedia(photo), author: 'Tu inspiración', source: '', imageUrl: '' }))); return;
      }
      if (req.method === 'DELETE' && /^\/v1\/inspirations\/[a-f0-9]{32}$/.test(path)) {
        const key = path.split('/').at(-1); const item = need('inspiration', key);
        store.transaction(() => { store.deleteMedia(item.imageId); store.delete('inspiration', key); const next = { ...votes() }; delete next[key]; store.set('votes', next); });
        json(res, 200, { ok: true }); return;
      }
      if (req.method === 'PUT' && path === '/v1/profile') {
        const input = await body(req); const next = { ...profile(), name: string(input.name, 60), notes: string(input.notes ?? '', 1200) };
        store.set('profile', next); json(res, 200, next); return;
      }
      if (req.method === 'PUT' && path === '/v1/body-photo') {
        const input = await body(req);
        if (input.consent !== true) fail(400, 'CONSENT', 'Confirma que deseas guardar esta foto como referencia del probador.');
        const photo = imageInput(input.image);
        const next = store.transaction(() => { const old = profile(); store.deleteMedia(old.bodyPhotoId); const next = { ...old, bodyPhotoId: store.addMedia(photo) }; store.set('profile', next); return next; });
        json(res, 200, next); return;
      }
      if (req.method === 'DELETE' && path === '/v1/body-photo') {
        store.transaction(() => { const old = profile(); store.deleteMedia(old.bodyPhotoId); store.set('profile', { ...old, bodyPhotoId: null });
          for (const l of store.all('look')) { store.deleteMedia(l.previewId); store.put('look', { ...l, previewId: null }); } });
        json(res, 200, { ok: true }); return;
      }
      if (req.method === 'POST' && path === '/v1/recommendations') {
        const input = await body(req); const occasion = string(input.occasion, 80, true); const notes = string(input.notes ?? '', 800);
        if (!canDress(store.all('garment'))) fail(400, 'MORE_CLOTHES', 'Añade un vestido o una prenda superior y una inferior para crear un look con tu ropa.');
        const response = await once(req, async () => {
          aiLimit(); const output = await providers.recommend({ ...context(), occasion, notes });
          if (!Array.isArray(output.outfits) || !output.outfits.length) fail(502, 'AI_NO_OUTFITS', 'La IA no encontró una combinación. Prueba con otra ocasión.');
          const unique = [...new Map(output.outfits.slice(0, 3).map(o => { const valid = validOutfit(o, store.all('garment')); return [[...valid.garmentIds].sort().join(','), valid]; })).values()];
          return store.transaction(() => ({ looks: unique.map(o => saveLook(o, occasion)) }));
        }); json(res, 200, response); return;
      }
      if (req.method === 'POST' && path === '/v1/chat') {
        const input = await body(req); const message = string(input.message, 2000, true);
        const selectedLook = input.lookId ? need('look', string(input.lookId, 32, true)) : null;
        const response = await once(req, async () => {
          if (chatBusy) fail(409, 'CHAT_BUSY', 'Espera a que Musa termine su respuesta.');
          chatBusy = true;
          try {
            aiLimit(); const output = await providers.chat({ ...context(), selectedLook }, store.all('message'), message);
            const reply = string(output.reply, 5000, true);
            // Validate before persisting either half of the conversation.
            if (output.outfit) validOutfit(output.outfit, store.all('garment'));
            return store.transaction(() => {
              const look = output.outfit ? saveLook(output.outfit, selectedLook?.occasion ?? 'A tu medida') : null;
              const user = store.put('message', { id: id(), created: Date.now(), role: 'user', text: message, lookId: selectedLook?.id ?? null });
              const assistant = store.put('message', { id: id(), created: Date.now(), role: 'assistant', text: reply, lookId: look?.id ?? null });
              const old = store.all('message'); for (const m of old.slice(0, Math.max(0, old.length - 1000))) store.delete('message', m.id);
              return { messages: [user, assistant], look };
            });
          } finally { chatBusy = false; }
        }); json(res, 200, response); return;
      }
      if (req.method === 'DELETE' && path === '/v1/chat') { if (chatBusy) fail(409, 'CHAT_BUSY', 'Espera a que termine la respuesta.'); store.db.prepare('DELETE FROM records WHERE kind=?').run('message'); json(res, 200, { ok: true }); return; }
      if (/^\/v1\/looks\/[a-f0-9]{32}$/.test(path)) {
        const key = path.split('/').at(-1); const old = need('look', key);
        if (req.method === 'PUT') { const input = await body(req); if (typeof input.saved !== 'boolean') fail(400, 'INVALID_INPUT', 'Indica si quieres guardar este look.'); json(res, 200, store.put('look', { ...old, saved: input.saved })); return; }
        if (req.method === 'DELETE') { if (previewBusy.has(key)) fail(409, 'PREVIEW_BUSY', 'Espera a que termine la imagen.'); removeLook(key); json(res, 200, { ok: true }); return; }
      }
      if (req.method === 'POST' && path === '/v1/previews') {
        const input = await body(req); const look = need('look', string(input.lookId, 32, true));
        const adjustment = string(input.adjustment ?? '', 500);
        if (input.consent !== true) fail(400, 'CONSENT', 'Confirma el envío de tu foto y prendas a Gemini para crear la imagen.');
        if (!config.geminiKey) fail(503, 'PREVIEW_NOT_CONFIGURED', 'Falta conectar Gemini para activar el probador.');
        const base = store.media(profile().bodyPhotoId ?? '');
        if (!base) fail(400, 'BASE_PHOTO_REQUIRED', 'Añade primero tu foto de cuerpo completo.');
        validOutfit(look, store.all('garment'));
        const clothes = look.garmentIds.map(key => store.media(need('garment', key).imageId));
        const response = await once(req, async () => {
          if (previewBusy.has(look.id)) fail(409, 'PREVIEW_BUSY', 'Ya se está generando una imagen para este look.');
          if (!store.limit(`images:${new Date().toISOString().slice(0, 10)}`, config.dailyPreviewLimit, 24 * 60 * 60_000)) fail(429, 'DAILY_PREVIEW_LIMIT', 'Alcanzaste el límite diario de imágenes de tu espacio.');
          previewBusy.add(look.id);
          try {
            const generated = imageInput(await providers.preview(base, clothes, look, adjustment));
            // Do not resurrect a deleted garment/look or a photo deleted while the provider worked.
            const current = need('look', look.id);
            if (profile().bodyPhotoId !== base.id) fail(409, 'PHOTO_CHANGED', 'Tu foto base cambió. La imagen generada se ha descartado.');
            validOutfit(current, store.all('garment'));
            return store.transaction(() => { store.deleteMedia(current.previewId); return { look: store.put('look', { ...current, previewId: store.addMedia(generated) }) }; });
          } finally { previewBusy.delete(look.id); }
        }); json(res, 200, response); return;
      }
      if (req.method === 'DELETE' && path === '/v1/data') {
        const input = await body(req);
        if (input.confirm !== 'BORRAR') fail(400, 'CONFIRM_DELETE', 'Escribe BORRAR para eliminar tu espacio.');
        if (chatBusy || previewBusy.size) fail(409, 'BUSY', 'Espera a que terminen las solicitudes de IA.');
        store.transaction(() => store.db.exec('DELETE FROM records; DELETE FROM media; DELETE FROM settings; DELETE FROM requests; DELETE FROM sessions;'));
        json(res, 200, { ok: true }); return;
      }
      fail(404, 'NOT_FOUND', 'Esta operación no está disponible.');
    } catch (error) {
      const known = error instanceof AppError;
      if (!known) console.error('Request failed:', error.name); // No personal payloads or provider secrets in logs.
      if (!res.headersSent) json(res, known ? error.status : 500, { error: { code: known ? error.code : 'INTERNAL_ERROR', message: known ? error.message : 'No se pudo completar la operación.' } });
      else res.end();
    }
  });
  server.requestTimeout = 210_000;
  server.headersTimeout = 15_000;
  return { server, store };
}
