# Compilar Musa para iPhone desde Windows

## 1. Subir el código

Crea un repositorio privado vacío en tu GitHub. No marques la creación de README allí. Desde PowerShell, dentro de la carpeta `musa`:

```powershell
git init
git branch -M main
git add .
git status
git commit -m "Musa: app Flutter de estilo personal"
git remote add origin https://github.com/TU_USUARIO/musa.git
git push -u origin main
```

Sustituye `TU_USUARIO` por tu cuenta. `git status` no debe mostrar `server/.env`: ya está excluido. Si Git pide identidad, configura tu nombre y correo con `git config` antes del commit.

## 2. Dirección del servidor

En el repositorio: **Settings → Secrets and variables → Actions → Variables → New repository variable**.

| Variable | Valor |
| --- | --- |
| `API_BASE_URL` | URL HTTPS pública de tu servidor Musa, sin `/v1` ni ruta final. |

Si aún no tienes hosting, puedes dejarla vacía: la app permitirá introducir la dirección luego. No se usa `localhost` como servidor del iPhone; `localhost` desde el teléfono significa el propio teléfono.

## 3. Generar la IPA sin firma

1. Abre **Actions → Build iOS → Run workflow**.
2. Elige `signing: unsigned`. `export_method` se ignora en esta modalidad.
3. Al terminar, abre la ejecución y descarga **Artifacts → Musa-iOS-unsigned-N**.
4. Extrae `Musa-unsigned.ipa`.

La app se compila para dispositivo físico ARM64, no para un simulador. El workflow ejecuta análisis y pruebas antes de compilar y no publica nada automáticamente.

## 4. Instalar en un iPhone

Una IPA sin firma **necesita una firma Apple** antes de instalarse. Hay dos rutas:

- **Uso personal con una herramienta de firma desde Windows:** utiliza una herramienta compatible con tu versión actual de iOS, como AltStore Classic o Sideloadly, y sigue su documentación oficial. Estas herramientas gestionan la firma con tu Apple ID; no hace falta poner tu contraseña de Apple en GitHub ni en Musa. Las cuentas gratuitas tienen restricciones y caducidad de firma; verifica las condiciones vigentes del instalador elegido.
- **Certificado y perfil Apple disponibles:** usa la modalidad `signed` del workflow. Los dispositivos y el tipo de distribución deben estar autorizados por el perfil.

No se han probado instaladores de terceros ni un iPhone físico en esta entrega. Fuentes oficiales para consultar compatibilidad y pasos actuales: [AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) y [Sideloadly](https://sideloadly.io/).

## Compilación firmada

En **Settings → Secrets and variables → Actions → Secrets**, crea:

| Secreto | Contenido |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Tu certificado de firma `.p12`, convertido a Base64. |
| `P12_PASSWORD` | Contraseña de ese `.p12`. |
| `BUILD_PROVISION_PROFILE_BASE64` | Tu perfil `.mobileprovision`, convertido a Base64. |

El perfil debe identificar exactamente **`com.milton.musa`**. La app no necesita una capacidad especial de Keychain Sharing: la sesión se guarda en el Keychain predeterminado de la aplicación.

Conversión en PowerShell, usando tus rutas reales:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\certificado.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\perfil.mobileprovision")) | Set-Clipboard
```

Ejecuta cada comando por separado y pega el resultado en el secreto correspondiente. Elige en Build iOS:

| `export_method` | Perfil requerido |
| --- | --- |
| `development` | Desarrollo; dispositivo autorizado por el perfil. |
| `ad-hoc` | Distribución Ad Hoc; UDID del iPhone incluido. |
| `app-store` | Distribución App Store; entrega posterior por App Store Connect/TestFlight. |

El script configura un llavero temporal, importa la firma, configura el target Runner y elimina las credenciales al terminar. La modalidad App Store solo crea el archivo; no lo sube ni lo publica.

## Si falla

- **No signing certificate / provisioning profile:** usa `unsigned` o revisa los tres secretos, el certificado y el perfil.
- **Perfil de otra app:** cambia el identificador del proyecto y la validación de `scripts/apple_signing.py` de forma coordinada, o crea un perfil para `com.milton.musa`.
- **No conecta al servidor:** verifica `https://tu-servidor/health`, el código privado y el acceso a Internet del teléfono.
- **No aparecen permisos de cámara:** reinstala la app o revisa Ajustes → Musa; las descripciones de permisos están incluidas en Info.plist.
- **Xcode o Flutter cambian:** el workflow fija Flutter 3.47.2 y usa macOS 15. La selección de Xcode del runner puede requerir actualización si GitHub cambia sus imágenes.
