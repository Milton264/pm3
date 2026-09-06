import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/app.mjs';
import { Store } from '../src/store.mjs';
import { Providers } from '../src/providers.mjs';
import { imageInput, styleProfile, validOutfit } from '../src/domain.mjs';

const image = { data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=' };
const config = { databasePath: ':memory:', pairingCode: 'a-strong-private-pairing-code', groqKey: 'test', geminiKey: '',
  allowedOrigins: ['http://localhost:8080'], dailyPreviewLimit: 3, chatModel: 'text-model', visionModel: 'vision-model', imageModel: 'image-model' };
async function fixture(t, overrides = {}, providerOverrides = {}) {
  let recommendations = 0; const baseReferences = [];
  const providers = {
    analyze: async () => ({ name: 'Camisa', category: 'top', colors: ['blanco'], tags: ['casual'] }),
    recommend: async c => { recommendations++; return { outfits: [{ title: 'Un día bonito', reason: 'Blanco y azul como tus referencias.', styling: 'Camisa por dentro.', garmentIds: c.wardrobe.map(g => g.id) }] }; },
    chat: async c => ({ reply: 'Podemos usar tus prendas con un aire casual.', outfit: c.wardrobe.length >= 2 ? { title: 'Otra idea', reason: 'Más relajado.', garmentIds: c.wardrobe.map(g => g.id) } : null }),
    preview: async (base, clothes) => { baseReferences.push(base.id); assert.ok(clothes.length); return image; }, ...providerOverrides
  };
  const app = createApp({ ...config, ...overrides }, { providers });
  await new Promise(r => app.server.listen(0, '127.0.0.1', r));
  t.after(async () => { await new Promise(r => app.server.close(r)); app.store.close(); });
  const baseUrl = `http://127.0.0.1:${app.server.address().port}`;
  let token;
  const request = async (method, path, data, headers = {}) => {
    const r = await fetch(`${baseUrl}${path}`, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers }, ...(data ? { body: JSON.stringify(data) } : {}) });
    return { status: r.status, data: await r.json() };
  };
  const login = await request('POST', '/v1/session', { code: config.pairingCode }); token = login.data.token;
  const add = async (category = 'top') => (await request('POST', '/v1/garments', { image, name: category, category, colors: ['blanco'], tags: ['casual'] })).data;
  return { ...app, request, add, baseUrl, baseReferences, recommendations: () => recommendations };
}

test('private wardrobe and photos require a session; invalid origin is rejected', async t => {
  const f = await fixture(t); const g = await f.add();
  assert.equal((await fetch(f.baseUrl + '/v1/bootstrap')).status, 401);
  assert.equal((await fetch(f.baseUrl + '/v1/media/' + g.imageId)).status, 401);
  assert.equal((await f.request('GET', '/v1/bootstrap', null, { Origin: 'https://untrusted.example' })).status, 403);
  assert.equal((await f.request('GET', '/v1/bootstrap')).data.garments.length, 1);
});
test('pairing rejects a wrong code and limits repeated attempts', async t => {
  const f = await fixture(t);
  for (let i = 0; i < 7; i++) assert.equal((await f.request('POST', '/v1/session', { code: 'wrong' })).status, 401);
  assert.equal((await f.request('POST', '/v1/session', { code: 'wrong' })).status, 429);
});
test('changing and undoing a vote updates the learned profile instead of duplicating weight', () => {
  const c = [{ id: 'a', tags: ['casual'] }, { id: 'b', tags: ['casual', 'denim'] }];
  assert.equal(styleProfile(c, { a: true, b: true }).favorites[0].tag, 'casual');
  assert.equal(styleProfile(c, { a: false, b: true }).favorites[0].tag, 'denim');
  assert.equal(styleProfile(c, {}).reviewed, 0);
});
test('votes accept removal and reject unknown references', async t => {
  const { request } = await fixture(t);
  assert.equal((await request('PUT', '/v1/votes', { votes: { blazer: true } })).data.votes.blazer, true);
  assert.equal((await request('PUT', '/v1/votes', { votes: { blazer: null } })).data.votes.blazer, undefined);
  assert.equal((await request('PUT', '/v1/votes', { votes: { invented: true } })).status, 400);
});
test('outfits cannot invent, duplicate, use paused clothes or omit a complete base', () => {
  const garments = [{ id: 'top', category: 'top', available: true }, { id: 'bottom', category: 'bottom', available: true }, { id: 'dress', category: 'dress', available: false }];
  const candidate = { title: 'look', reason: 'style' };
  for (const ids of [['ghost'], ['top'], ['top', 'top', 'bottom'], ['dress'], ['top', 'dress']])
    assert.throws(() => validOutfit({ ...candidate, garmentIds: ids }, garments));
  assert.equal(validOutfit({ ...candidate, garmentIds: ['top', 'bottom'] }, garments).garmentIds.length, 2);
});
test('recommendations persist and idempotency prevents duplicate model calls', async t => {
  const f = await fixture(t); await f.add('top'); await f.add('bottom');
  const key = { 'Idempotency-Key': 'recommendation_12345' };
  const first = await f.request('POST', '/v1/recommendations', { occasion: 'Una cita' }, key);
  const second = await f.request('POST', '/v1/recommendations', { occasion: 'Una cita' }, key);
  assert.equal(first.status, 200); assert.deepEqual(first, second); assert.equal(f.recommendations(), 1);
  assert.equal((await f.request('GET', '/v1/bootstrap')).data.looks.length, 1);
});
test('invalid AI output does not persist looks or either chat message', async t => {
  const f = await fixture(t, {}, { chat: async () => ({ reply: 'Use this', outfit: { title: 'Bad', reason: 'Bad', garmentIds: ['ghost'] } }) });
  const r = await f.request('POST', '/v1/chat', { message: 'Cambia el look' }, { 'Idempotency-Key': 'invalid_chat_1234' });
  assert.equal(r.status, 502); assert.equal(f.store.all('message').length, 0); assert.equal(f.store.all('look').length, 0);
});
test('chat stores a real alternative while keeping the original look', async t => {
  const f = await fixture(t); await f.add('top'); await f.add('bottom');
  const original = (await f.request('POST', '/v1/recommendations', { occasion: 'Día a día' }, { 'Idempotency-Key': 'original_look_123' })).data.looks[0];
  const r = await f.request('POST', '/v1/chat', { message: 'Más casual', lookId: original.id }, { 'Idempotency-Key': 'change_look_1234' });
  assert.equal(r.status, 200); assert.notEqual(r.data.look.id, original.id);
  assert.equal(f.store.all('look').length, 2); assert.equal(f.store.all('message').length, 2);
});
test('preview is unavailable without provider setup, never returns a fake image', async t => {
  const f = await fixture(t); await f.add('dress');
  const l = (await f.request('POST', '/v1/recommendations', { occasion: 'Evento' }, { 'Idempotency-Key': 'single_dress_1234' })).data.looks[0];
  const r = await f.request('POST', '/v1/previews', { lookId: l.id, consent: true }, { 'Idempotency-Key': 'preview_1234567' });
  assert.equal(r.status, 503); assert.equal(r.data.error.code, 'PREVIEW_NOT_CONFIGURED');
});
test('every generated version starts from original photo; deleting base also deletes previews', async t => {
  const f = await fixture(t, { geminiKey: 'test' }); await f.add('dress');
  const base = (await f.request('PUT', '/v1/body-photo', { image, consent: true })).data.bodyPhotoId;
  const look = (await f.request('POST', '/v1/recommendations', { occasion: 'Evento' }, { 'Idempotency-Key': 'dress_123456789' })).data.looks[0];
  assert.equal((await f.request('POST', '/v1/previews', { lookId: look.id, consent: false }, { 'Idempotency-Key': 'no_consent_12345' })).status, 400);
  for (const key of ['preview_first_123', 'preview_second_123']) {
    const r = await f.request('POST', '/v1/previews', { lookId: look.id, consent: true }, { 'Idempotency-Key': key }); assert.equal(r.status, 200);
  }
  assert.deepEqual(f.baseReferences, [base, base]);
  const preview = f.store.get('look', look.id).previewId;
  await f.request('DELETE', '/v1/body-photo');
  assert.equal(f.store.media(base), undefined); assert.equal(f.store.media(preview), undefined); assert.equal(f.store.get('look', look.id).previewId, null);
});
test('deleting a garment removes dependent looks and its private photo', async t => {
  const f = await fixture(t); const garment = await f.add('dress');
  await f.request('POST', '/v1/recommendations', { occasion: 'Evento' }, { 'Idempotency-Key': 'deletion_look_123' });
  await f.request('DELETE', '/v1/garments/' + garment.id);
  assert.equal(f.store.all('look').length, 0); assert.equal(f.store.media(garment.imageId), undefined);
});
test('data survives a server restart', () => {
  const dir = mkdtempSync(join(tmpdir(), 'musa-test-')); const path = join(dir, 'app.sqlite');
  try { const first = new Store(path); first.set('profile', { name: 'Ana' }); first.close(); const second = new Store(path);
    assert.equal(second.setting('profile').name, 'Ana'); second.close(); } finally { rmSync(dir, { recursive: true }); }
});
test('upload validation rejects scripts and malformed image data', () => {
  assert.throws(() => imageInput({ data: Buffer.from('<svg onload="bad()"></svg>').toString('base64') }));
  assert.throws(() => imageInput({ data: 'invalid$$' })); assert.equal(imageInput(image).mime, 'image/png');
});
test('Gemini adapter sends original plus garment images and reads REST model_output', async () => {
  let request;
  const providers = new Providers({ ...config, geminiKey: 'not-a-real-key' }, async (url, init) => {
    request = { url, body: JSON.parse(init.body) };
    return Response.json({ steps: [{ type: 'model_output', content: [{ type: 'image', mime_type: 'image/png', data: image.data }] }] });
  });
  const result = await providers.preview(imageInput(image), [imageInput(image)], { title: 'look', styling: 'casual' }, 'mangas remangadas');
  assert.equal(result.data, image.data); assert.equal(request.body.store, false); assert.equal(request.body.input.filter(p => p.type === 'image').length, 2);
});
test('provider rate limits are truthful and provider error bodies never leak', async () => {
  const provider = new Providers(config, async () => Response.json({ error: { message: 'private prompt or credential' } }, { status: 429 }));
  await assert.rejects(provider.groq([]), e => e.code === 'AI_QUOTA' && !e.message.includes('private'));
});
