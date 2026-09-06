# Servidor privado de Musa

## Para qué sirve

El teléfono se conecta a este servidor. Aquí viven la clave Groq, la clave Gemini opcional, las fotos, el armario, las preferencias y las conversaciones. El diseño actual es para **una sola usuaria por instancia**. El código de acceso permite entrar a ese mismo espacio desde varios dispositivos.

No hay una base de datos externa que contratar. Node.js 24 incluye el controlador SQLite utilizado. `npm start` no requiere instalar paquetes del servidor.

## Configuración

| Variable | Uso |
| --- | --- |
| `GROQ_API_KEY` | Clave privada para visión, recomendaciones y chat. |
| `GROQ_CHAT_MODEL` | Predeterminado: `openai/gpt-oss-120b`. |
| `GROQ_VISION_MODEL` | Predeterminado: `qwen/qwen3.6-27b`. |
| `GEMINI_API_KEY` | Opcional; habilita el probador. |
| `GEMINI_IMAGE_MODEL` | Predeterminado: `gemini-3.1-flash-image`. |
| `PAIRING_CODE` | Código privado largo para vincular el teléfono. |
| `DATA_DIR` | Carpeta de datos; por defecto `server/data` al iniciar desde `server`. |
| `PORT` | Puerto, por defecto `8787`. |
| `HOST` | Interfaz de escucha, por defecto `0.0.0.0`. |
| `ALLOWED_ORIGINS` | Orígenes web permitidos separados por comas. La app móvil nativa no requiere CORS. |
| `DAILY_PREVIEW_LIMIT` | Máximo de intentos de generación al día, por defecto 10. Los fallidos también cuentan. |

Los modelos son configurables porque los proveedores pueden retirarlos. Para comprobar la credencial y los modelos:

```powershell
cd server
npm run check:groq
```

## Docker

Desde la raíz del proyecto:

```bash
docker compose up -d --build
```

El contenedor guarda los datos en el volumen `musa-data`. El puerto del host se vincula a `127.0.0.1:8787`, preparado para un proxy HTTPS. La imagen no contiene `.env`, fotos ni bases de datos. Docker recibe las variables al iniciar.

Ejemplo de configuración de Caddy en un servidor con tu dominio apuntando a él:

```caddy
musa.tudominio.com {
    reverse_proxy 127.0.0.1:8787
}
```

Sustituye el dominio. El despliegue requiere un servidor que ejecute Node o Docker y tenga almacenamiento persistente. GitHub Pages no ejecuta este backend. No se ha desplegado un hosting automáticamente.

## Desarrollo local

La versión web puede usarse en `http://localhost:8080` junto al servidor local. En Android emulado, el host suele ser `10.0.2.2`; para pruebas HTTP usa una configuración de desarrollo explícita o un túnel HTTPS. La compilación Android de distribución conserva la política de red segura.

En iOS se permite el descubrimiento de red local; para uso habitual se recomienda la URL HTTPS del servidor. El permiso de red local no garantiza que todas las versiones de iOS admitan cualquier dirección HTTP literal.

## Datos y eliminación

- Las sesiones duran 90 días, se almacenan con hash en el servidor y mediante almacenamiento seguro en el dispositivo.
- Las fotos solo se sirven con una sesión válida; no tienen enlaces públicos.
- Las fotos se normalizan en el cliente y el servidor retira metadatos de JPG/PNG antes de guardarlas o enviarlas a la IA.
- La foto base se envía a Gemini al generar y con consentimiento. No se envía a Groq para inferir atributos de la persona.
- Borrar la foto base elimina también las vistas previas guardadas. Borrar una prenda elimina los looks que dependían de ella.
- Los gustos pendientes se conservan en el teléfono y se sincronizan cuando regresa la conexión. El armario y el chat requieren el servidor.
- `Mi espacio → Borrar todos mis datos` elimina los datos activos y revoca las sesiones. No elimina copias de seguridad que el administrador haya creado.

Para respaldar SQLite usa su API de copia de seguridad o detén el servidor antes de copiar **todo** el directorio de datos. No copies únicamente `musa.sqlite` mientras el proceso esté escribiendo en modo WAL. El volumen debe persistir entre despliegues; no uses almacenamiento efímero para las fotos personales.

La eliminación activa es lógica a nivel SQLite y no equivale a borrado forense del disco. Usa un volumen cifrado y controla las copias si necesitas garantías adicionales.
