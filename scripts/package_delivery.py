"""Create a portable source archive, excluding local build and runtime data."""
import argparse
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--with-private-env', action='store_true', help='Incluir server/.env solo en una entrega privada al propietario.')
parser.add_argument('--output', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = Path(args.output).resolve()
excluded_dirs = {'.git', '.dart_tool', '.gradle', '.idea', '.vscode', 'build', 'node_modules', 'ephemeral', 'Pods', '.symlinks', 'qa', '__pycache__', 'data'}
excluded_names = {'local.properties', 'Generated.xcconfig', 'flutter_export_environment.sh', '.flutter-plugins-dependencies', '.DS_Store', '.packages'}
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=8) as archive:
    for file in sorted(root.rglob('*')):
        if not file.is_file() or file.is_symlink() or file.resolve() == output:
            continue
        rel = file.relative_to(root)
        if any(part in excluded_dirs for part in rel.parts) or file.name in excluded_names:
            continue
        if file.suffix in {'.zip', '.ipa', '.apk', '.iml', '.p12', '.mobileprovision', '.log', '.pyc'}:
            continue
        if file.name.startswith('.env') and file.name != '.env.example':
            if not (args.with_private_env and rel.as_posix() == 'server/.env'):
                continue
        if rel.as_posix() in {'config/local.json', 'config/build.json'}:
            continue
        archive.write(file, f'musa/{rel.as_posix()}')
print(f'Proyecto empaquetado: {output.name} ({output.stat().st_size:,} bytes).')
