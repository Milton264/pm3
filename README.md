# Musa

Una aplicación personal de estilo para Flutter, creada para Milton y su novia. Interfaz en español, fondo marfil, ciruela, ilustraciones propias, fotografías grandes y animaciones de deslizamiento.

## Qué incluye

- **Descubrir:** ocho fotografías iniciales con licencia Unsplash. Derecha/verde/«Muy yo» guarda el gusto; izquierda/rojo/«Paso» lo descarta. Botón para deshacer y tablero con favoritos. Se pueden añadir más referencias desde las fotos del teléfono.
- **Armario:** cámara o galería, reconocimiento visual real con Groq, corrección manual, categorías, colores, etiquetas, búsqueda y prendas temporalmente en pausa.
- **Mis looks:** combinaciones de las prendas disponibles, según gustos, ocasión y preferencias. Cada propuesta explica su selección; puedes guardarla o eliminarla.
- **Chat:** conversación real con Groq, con memoria del historial, gustos y armario. Pedir cambios crea una nueva versión del look y mantiene la anterior.
- **Probador:** foto original persistente, integración de generación/edición con Gemini, referencias de las prendas seleccionadas, comparación original/resultado y ajustes mediante texto. Requiere `GEMINI_API_KEY` con generación de imágenes habilitada.
- **Servidor privado:** Node.js 24 y SQLite, sin dependencias npm. Sesiones mediante código de acceso, fotos protegidas, límites de uso, eliminación de datos y persistencia en disco.
- **GitHub Actions:** compilación iOS sin firma o firmada, verificación automática y compilación Android personal.

El armario empieza vacío: las prendas, fotos personales y conversaciones las añade la usuaria. Las fotografías iniciales son referencias de estilo, no prendas de su armario. No hay conexión automática a una cuenta de Pinterest.

## Arranque rápido en Windows

Requisitos: **Flutter 3.47.2**, **Node.js 24** y Git. La compilación para iPhone se realiza en el Mac de GitHub Actions; no necesitas un Mac local para producir el archivo sin firma.

1. Extrae el ZIP. Abre una terminal dentro de la carpeta `musa`.
2. Inicia el servidor:

```powershell
cd server
npm start
```

3. En otra terminal, desde la raíz `musa`:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

4. Abre **Mi espacio → Conectar mi espacio**. Usa `http://127.0.0.1:8787` y el valor `PAIRING_CODE` de `server/.env`.

**La entrega privada incluye tu clave de Groq configurada en `server/.env`.** Ese archivo y la base de datos están excluidos de Git y Docker. GitHub Actions no necesita la clave de Groq: el teléfono llama al servidor. Sigue el flujo de Git indicado en la guía; no cargues el `.env` manualmente al repositorio.

Si obtienes el proyecto desde un repositorio sin `.env`, ejecuta `node scripts/setup.mjs` y añade la clave en el archivo creado. El script conserva cualquier configuración que ya exista.

## iPhone y GitHub Actions

Consulta **[docs/IOS_WINDOWS.md](docs/IOS_WINDOWS.md)**. El workflow **Build iOS** admite:

| Modalidad | Resultado | Lo que hace falta |
| --- | --- | --- |
| `unsigned` | `Musa-unsigned.ipa` para iPhone ARM64 | Firmarla después para instalarla. |
| `signed` | IPA firmada | Certificado `.p12`, contraseña y perfil Apple válidos para `com.milton.musa`. |

El archivo sin firma no se instala simplemente tocándolo desde el iPhone. Compilar y autorizar su instalación son pasos distintos.

Para usar la app fuera de tu PC, aloja el servidor con HTTPS. Configura la variable de repositorio `API_BASE_URL` antes de compilar o introduce la dirección desde la app. El código de acceso se introduce en el teléfono, no se incrusta en el binario.

## Activar el probador

En `server/.env`:

```dotenv
GEMINI_API_KEY=tu_clave_de_gemini
GEMINI_IMAGE_MODEL=gemini-3.1-flash-image
DAILY_PREVIEW_LIMIT=10
```

Reinicia el servidor y sincroniza desde Mi espacio. Sube la foto base y abre un look → **Ver cómo se vería en mí**. La app pide permiso para enviar la foto y las prendas al proveedor de imágenes.

Groq se utiliza para comprender imágenes y conversar; el probador genera la imagen con Gemini. La generación puede tener un costo según la cuenta. Cada intento usa la foto original, no la última imagen generada. Es una aproximación visual: no garantiza fidelidad exacta de identidad, estampados o ajuste de la ropa.

## Verificación realizada

- Análisis estático y compilación Flutter Web de producción.
- 7 pruebas Flutter: deslizamiento, votos, deshacer, acceso privado, tamaños compactos, teclado y renderizado visual.
- 15 pruebas del servidor: autenticación, persistencia, recomendaciones, chat, consistencia de prendas, idempotencia y contratos de generación.
- Llamadas reales con tu credencial Groq: modelos disponibles, reconocimiento de blazer, recomendación con IDs válidos y respuesta contextual por chat.
- Revisión visual de capturas renderizadas por Flutter.

La compilación nativa de iOS está preparada para GitHub Actions y debe ejecutarse allí. El entorno de desarrollo usado para esta entrega es Linux. El probador se verificó con pruebas del contrato de su API; no se hizo una generación real porque falta la credencial Gemini y una foto base de la usuaria.

## Estructura

```text
lib/                    Aplicación Flutter: pantallas, estado, API y diseño
assets/                 Catálogo, fotografías, fuentes y marca
ios/ android/ web/      Proyectos de plataforma
server/src/             Servidor, SQLite, validaciones y adaptadores de IA
server/test/            Pruebas del servidor
test/                   Pruebas Flutter
scripts/                Configuración y empaquetado iOS
.github/workflows/      Compilación y verificación
docs/                   Instalación, servidor, arquitectura y fuentes
```

Más detalles: [servidor](docs/SERVIDOR.md), [arquitectura](docs/ARQUITECTURA.md) y [fuentes](docs/FUENTES.md).
