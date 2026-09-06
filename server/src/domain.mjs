import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

export class AppError extends Error {
  constructor(status, code, message) { super(message); Object.assign(this, { status, code }); }
}
export const fail = (status, code, message) => { throw new AppError(status, code, message); };
export const id = () => randomBytes(16).toString('hex');
export const hash = value => createHash('sha256').update(value).digest('hex');
export const sameSecret = (a, b) => timingSafeEqual(Buffer.from(hash(a)), Buffer.from(hash(b)));
export const categories = ['top', 'bottom', 'dress', 'outerwear', 'shoes', 'bag', 'accessory'];
export function string(value, max = 160, required = false) {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim()))
    fail(400, 'INVALID_INPUT', 'Revisa los datos introducidos.');
  return value.trim();
}
export function tags(value, max = 12) {
  if (!Array.isArray(value) || value.length > max) fail(400, 'INVALID_TAGS', 'Usa una lista breve de etiquetas.');
  return [...new Set(value.map(v => string(v, 40, true).toLowerCase()))];
}
export function garmentInput(body) {
  if (!categories.includes(body.category)) fail(400, 'INVALID_CATEGORY', 'Elige un tipo de prenda.');
  return { name: string(body.name, 80, true), category: body.category,
    colors: tags(body.colors ?? [], 6), tags: tags(body.tags ?? []),
    notes: string(body.notes ?? '', 500), available: body.available !== false };
}
export function styleProfile(catalog, votes) {
  const scores = new Map();
  for (const item of catalog) {
    if (typeof votes[item.id] !== 'boolean') continue;
    for (const tag of item.tags) {
      const current = scores.get(tag) ?? { tag, liked: 0, disliked: 0 };
      current[votes[item.id] ? 'liked' : 'disliked']++;
      scores.set(tag, current);
    }
  }
  const preferences = [...scores.values()].map(s => ({ ...s, score: (s.liked - s.disliked) / (s.liked + s.disliked + 2) }));
  return { reviewed: Object.values(votes).filter(v => typeof v === 'boolean').length,
    liked: Object.values(votes).filter(v => v === true).length,
    favorites: preferences.filter(s => s.score > 0).sort((a, b) => b.score - a.score).slice(0, 10),
    avoid: preferences.filter(s => s.score < 0).sort((a, b) => a.score - b.score).slice(0, 10) };
}
export function validOutfit(candidate, garments) {
  if (!candidate || !Array.isArray(candidate.garmentIds) || candidate.garmentIds.length < 1 || candidate.garmentIds.length > 7)
    fail(502, 'AI_INVALID_OUTFIT', 'La IA no devolvió un conjunto válido. Inténtalo de nuevo.');
  const ids = candidate.garmentIds;
  const selected = ids.map(i => garments.find(g => g.id === i && g.available));
  if (new Set(ids).size !== ids.length || selected.some(g => !g))
    fail(502, 'AI_UNKNOWN_GARMENT', 'La propuesta incluía una prenda que no está disponible. Pide otra combinación.');
  const counts = {};
  for (const g of selected) counts[g.category] = (counts[g.category] ?? 0) + 1;
  if (!(counts.dress === 1 || (counts.top === 1 && counts.bottom === 1)) ||
      (counts.dress && (counts.top || counts.bottom)) ||
      Object.entries(counts).some(([k, n]) => n > (k === 'accessory' ? 2 : 1)))
    fail(502, 'AI_INCOMPLETE_OUTFIT', 'La combinación no forma un conjunto completo. Pide otra propuesta.');
  return { title: string(candidate.title, 80, true), reason: string(candidate.reason, 1400, true),
    styling: string(candidate.styling ?? '', 1000), garmentIds: ids };
}
export function canDress(garments) {
  const c = garments.filter(g => g.available).map(g => g.category);
  return c.includes('dress') || (c.includes('top') && c.includes('bottom'));
}

// Only raster files; strip JPEG metadata (including GPS) before persistence/provider calls.
export function imageInput(input) {
  if (!input || typeof input.data !== 'string' || input.data.length > 11_200_000 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(input.data)) fail(400, 'INVALID_IMAGE', 'Elige una fotografía JPG o PNG de hasta 8 MB.');
  let bytes = Buffer.from(input.data, 'base64');
  if (bytes.length < 24 || bytes.length > 8 * 1024 * 1024) fail(413, 'IMAGE_TOO_LARGE', 'La fotografía debe ocupar menos de 8 MB.');
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    if (bytes.readUInt32BE(16) > 8000 || bytes.readUInt32BE(20) > 8000) fail(400, 'IMAGE_DIMENSIONS', 'Reduce la fotografía a menos de 8000 píxeles.');
    let offset = 8; const chunks = [bytes.subarray(0, 8)]; let hasData = false, ended = false;
    while (offset + 12 <= bytes.length) {
      const length = bytes.readUInt32BE(offset); const type = bytes.toString('ascii', offset + 4, offset + 8);
      if (offset + 12 + length > bytes.length) fail(400, 'INVALID_IMAGE', 'El archivo PNG está incompleto.');
      if (['IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS'].includes(type)) chunks.push(bytes.subarray(offset, offset + 12 + length));
      if (type === 'IDAT') hasData = true;
      offset += length + 12;
      if (type === 'IEND') { ended = true; break; }
    }
    if (!hasData || !ended) fail(400, 'INVALID_IMAGE', 'El archivo PNG está incompleto.');
    return { mime: 'image/png', bytes: Buffer.concat(chunks) };
  }
  if (bytes[0] === 255 && bytes[1] === 216) {
    const chunks = [bytes.subarray(0, 2)]; let offset = 2, foundScan = false;
    while (offset + 4 < bytes.length) {
      if (bytes[offset] !== 255) break;
      const marker = bytes[offset + 1];
      if (marker === 0xda) { chunks.push(bytes.subarray(offset)); foundScan = true; break; }
      const length = bytes.readUInt16BE(offset + 2);
      if (length < 2 || offset + 2 + length > bytes.length) break;
      if (![0xe1, 0xed, 0xfe].includes(marker)) chunks.push(bytes.subarray(offset, offset + 2 + length));
      offset += 2 + length;
    }
    if (!foundScan) fail(400, 'INVALID_IMAGE', 'El archivo JPG no se puede leer.');
    return { mime: 'image/jpeg', bytes: Buffer.concat(chunks) };
  }
  fail(400, 'INVALID_IMAGE', 'Selecciona una fotografía JPG o PNG.');
}
