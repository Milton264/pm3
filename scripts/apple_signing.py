"""Temporary signing setup on a GitHub-hosted macOS runner; no secrets are printed."""
import base64
import json
import os
from pathlib import Path
import plistlib
import secrets
import subprocess
import sys

temp = Path(os.environ['RUNNER_TEMP'])
keychain = temp / 'musa-signing.keychain-db'
manifest = temp / 'musa-signing-files.json'

if '--cleanup' in sys.argv:
    subprocess.run(['security', 'delete-keychain', str(keychain)], capture_output=True)
    if manifest.exists():
        for file in json.loads(manifest.read_text()):
            Path(file).unlink(missing_ok=True)
    for file in ['musa-certificate.p12', 'musa-profile.mobileprovision', 'musa-profile.plist', 'ExportOptions.plist', 'musa-signing-files.json']:
        (temp / file).unlink(missing_ok=True)
    raise SystemExit(0)

for key in ['BUILD_CERTIFICATE_BASE64', 'P12_PASSWORD', 'BUILD_PROVISION_PROFILE_BASE64']:
    if not os.environ.get(key):
        raise SystemExit(f'Configura el secreto {key} o elige compilación unsigned.')
certificate = temp / 'musa-certificate.p12'
profile_file = temp / 'musa-profile.mobileprovision'
certificate.write_bytes(base64.b64decode(''.join(os.environ['BUILD_CERTIFICATE_BASE64'].split()), validate=True))
profile_file.write_bytes(base64.b64decode(''.join(os.environ['BUILD_PROVISION_PROFILE_BASE64'].split()), validate=True))
certificate.chmod(0o600)
profile_file.chmod(0o600)
result = subprocess.run(['security', 'cms', '-D', '-i', str(profile_file)], capture_output=True, check=True)
profile = plistlib.loads(result.stdout)
team = profile['TeamIdentifier'][0]
name = profile['Name']
bundle = profile['Entitlements']['application-identifier'].split('.', 1)[1]
if bundle != 'com.milton.musa':
    raise SystemExit('El perfil debe corresponder exactamente al bundle com.milton.musa.')
password = secrets.token_urlsafe(32)
for command in [
    ['security', 'create-keychain', '-p', password, str(keychain)],
    ['security', 'set-keychain-settings', '-lut', '21600', str(keychain)],
    ['security', 'unlock-keychain', '-p', password, str(keychain)],
    ['security', 'import', str(certificate), '-P', os.environ['P12_PASSWORD'], '-A', '-t', 'cert', '-f', 'pkcs12', '-k', str(keychain)],
    ['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', password, str(keychain)],
    ['security', 'list-keychain', '-d', 'user', '-s', str(keychain)],
]:
    process = subprocess.run(command, capture_output=True)
    if process.returncode:
        raise SystemExit('No se pudo importar la firma Apple. Revisa certificado, contraseña y perfil.')

installed = []
for directory in [Path.home() / 'Library/MobileDevice/Provisioning Profiles', Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles']:
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / f'{profile["UUID"]}.mobileprovision'
    target.write_bytes(profile_file.read_bytes())
    installed.append(str(target))
manifest.write_text(json.dumps(installed))

identity = 'Apple Development' if profile['Entitlements'].get('get-task-allow') else 'Apple Distribution'
pbxproj = Path('ios/Runner.xcodeproj/project.pbxproj')
content = pbxproj.read_text()
marker = 'PRODUCT_BUNDLE_IDENTIFIER = com.milton.musa;'
replacement = marker + '\n' + '\n'.join(f'                {k} = {json.dumps(v)};' for k, v in {
    'DEVELOPMENT_TEAM': team, 'CODE_SIGN_STYLE': 'Manual', 'CODE_SIGN_IDENTITY': identity,
    'PROVISIONING_PROFILE_SPECIFIER': name}.items())
if content.count(marker) != 3:
    raise SystemExit('La estructura del proyecto cambió: revisa manualmente la configuración de firma.')
pbxproj.write_text(content.replace(marker, replacement))
method = {'development': 'debugging', 'ad-hoc': 'release-testing', 'app-store': 'app-store-connect'}[os.environ.get('EXPORT_METHOD', 'development')]
options = {'method': method, 'teamID': team, 'signingStyle': 'manual', 'signingCertificate': identity,
           'provisioningProfiles': {'com.milton.musa': name}, 'stripSwiftSymbols': True, 'uploadSymbols': False,
           'manageAppVersionAndBuildNumber': False}
with (temp / 'ExportOptions.plist').open('wb') as file:
    plistlib.dump(options, file)
print('Firma configurada para compilar Musa. No se publicará automáticamente en App Store.')
