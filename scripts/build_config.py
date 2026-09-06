"""Write only public runtime settings. Provider keys never belong in dart-define."""
import json
import os
from pathlib import Path
from urllib.parse import urlparse

url = os.environ.get('API_BASE_URL', '').strip().rstrip('/')
if url:
    parsed = urlparse(url)
    if parsed.scheme != 'https' or not parsed.netloc or parsed.username or parsed.query or parsed.fragment or parsed.path:
        raise SystemExit('API_BASE_URL debe ser una URL HTTPS sin ruta, credenciales ni parámetros.')
else:
    print('API_BASE_URL no está configurada: la app solicitará la dirección al conectar el espacio.')
Path('config').mkdir(exist_ok=True)
Path('config/build.json').write_text(json.dumps({'API_BASE_URL': url}))
