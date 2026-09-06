const key = process.env.GROQ_API_KEY;
if (!key) { console.error('Falta GROQ_API_KEY en server/.env'); process.exit(1); }
try {
 const r = await fetch('https://api.groq.com/openai/v1/models', { headers:{Authorization:`Bearer ${key}`}, signal:AbortSignal.timeout(30000) });
 if (!r.ok) { console.error(`Groq respondió HTTP ${r.status}; revisa la clave y sus permisos.`); process.exit(1); }
 const data = await r.json();
 for (const model of [process.env.GROQ_CHAT_MODEL,process.env.GROQ_VISION_MODEL].filter(Boolean)) {
  console.log(`${model}: ${data.data?.some(m=>m.id===model)?'disponible':'no disponible en esta cuenta'}`);
 }
 console.log('Credencial validada con Groq.');
} catch { console.error('No se pudo conectar con Groq desde este entorno.'); process.exit(1); }
