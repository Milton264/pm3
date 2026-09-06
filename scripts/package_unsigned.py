"""Create a correctly structured IPA. It still requires Apple signing before installation."""
from pathlib import Path
import shutil
import subprocess

app = Path('build/ios/iphoneos/Runner.app')
if not app.is_dir():
    raise SystemExit('No existe Runner.app: la compilación iOS debe terminar primero.')
output = Path('build/ios/ipa')
output.mkdir(parents=True, exist_ok=True)
payload = output / 'Payload'
if payload.exists():
    shutil.rmtree(payload)
payload.mkdir()
# ditto and zip preserve the bundle and framework symlinks.
subprocess.run(['ditto', str(app), str(payload / 'Runner.app')], check=True)
subprocess.run(['zip', '-qry', 'Musa-unsigned.ipa', 'Payload'], cwd=output, check=True)
shutil.rmtree(payload)
(output / 'LEEME.txt').write_text(
    'Musa-unsigned.ipa está compilada para iPhone ARM64, pero NO está firmada.\n'
    'Necesita firmarse con tu Apple ID o con un certificado/perfil válidos antes de instalarla.\n'
    'No se instala tocando el archivo desde Safari. Consulta docs/IOS_WINDOWS.md.\n', encoding='utf-8')
