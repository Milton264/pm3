# Arquitectura y funcionamiento

## Recorrido de los datos

Flutter muestra el catálogo local y registra cada voto. Al conectar el espacio, sincroniza los cambios pendientes. Las fotografías nuevas viajan al servidor autenticado; Groq devuelve una descripción editable. El servidor almacena únicamente los detalles confirmados y la foto cuando se guarda la prenda.

Para recomendar, el servidor construye el contexto con el armario disponible, preferencias explícitas, votos positivos/negativos y ocasión. Groq responde con JSON. La validación exige identificadores existentes y una base vestible: vestido, o top más parte inferior. Rechaza duplicados y prendas en pausa. El resultado se guarda después de validarlo.

El chat incluye las últimas 16 intervenciones, el contexto actualizado y el look seleccionado. Si devuelve una alternativa válida, se guarda como un nuevo look; el original permanece. El historial persistido admite hasta 1000 mensajes y la app carga los últimos 100.

Para generar una vista previa se envían a Gemini la foto original y las imágenes de todas las prendas del look. Cada nueva generación parte de la foto original. Se solicita preservar identidad, proporciones, encuadre y detalles de las prendas, pero un modelo generativo no garantiza fidelidad exacta. La app identifica el resultado como imagen generada.

## Aprendizaje del gusto

Cada imagen tiene etiquetas estéticas. Para cada etiqueta se calcula:

`puntuación = (votos positivos − votos negativos) / (apariciones votadas + 2)`

El término `+2` reduce la confianza excesiva en una sola imagen. Las imágenes no vistas no cuentan. Cambiar un voto reemplaza el anterior y deshacer lo retira o restaura. Las mejores etiquetas y las rechazadas forman parte del contexto enviado a Groq; no se reentrena un modelo desde cero.

## Persistencia

| Entidad | Contenido |
| --- | --- |
| Prenda | ID, nombre, categoría, colores, etiquetas, notas, disponibilidad, imagen. |
| Referencia propia | ID, título, etiquetas, autor, imagen. |
| Look | ID, prendas, ocasión, explicación, consejos, guardado, imagen de vista previa. |
| Mensaje | ID, rol, texto, look relacionado, fecha. |
| Perfil | Nombre, preferencias escritas, foto base. |
| Voto | Referencia y decisión, con sincronización pendiente en el teléfono. |
| Medio | Imagen binaria privada, MIME y fecha. |
| Sesión | Hash del token y caducidad. |
| Solicitud | Clave de idempotencia y resultado durante 24 horas. |

SQLite utiliza `records` para los documentos de las entidades, `media` para los binarios y tablas separadas para sesiones, ajustes, cuotas e idempotencia. Las referencias entre documentos se validan en la aplicación. Los borrados coordinados y las escrituras de chat usan transacciones.

## API principal

| Método y ruta | Operación |
| --- | --- |
| `GET /health` | Estado del proceso sin datos privados. |
| `POST /v1/session` | Vincular dispositivo mediante código privado. |
| `DELETE /v1/session` | Revocar la sesión actual. |
| `GET /v1/bootstrap` | Cargar datos del espacio autenticado. |
| `PUT /v1/votes` | Fusionar votos; `null` elimina una decisión. |
| `POST /v1/analyze` | Analizar una prenda o inspiración con Groq. |
| `POST /v1/garments` | Guardar una prenda y su foto. |
| `PUT /v1/garments/:id` | Editar detalles o disponibilidad. |
| `DELETE /v1/garments/:id` | Borrar prenda y looks dependientes. |
| `POST /v1/inspirations` | Añadir referencia propia. |
| `DELETE /v1/inspirations/:id` | Eliminar referencia propia. |
| `POST /v1/recommendations` | Crear looks según ocasión. |
| `POST /v1/chat` | Conversar y crear alternativas. |
| `DELETE /v1/chat` | Borrar historial. |
| `PUT /v1/looks/:id` | Guardar/quitar favorito. |
| `DELETE /v1/looks/:id` | Eliminar look y vista previa. |
| `PUT /v1/profile` | Nombre y preferencias explícitas. |
| `PUT /v1/body-photo` | Guardar/reemplazar foto original. |
| `DELETE /v1/body-photo` | Borrar original y vistas previas. |
| `POST /v1/previews` | Generar vista previa con consentimiento. |
| `GET /v1/media/:id` | Obtener imagen con autenticación. |
| `DELETE /v1/data` | Eliminar espacio con confirmación escrita. |

Las solicitudes de recomendaciones, chat y vistas previas requieren `Idempotency-Key`. El servidor evita duplicar una solicitud ya terminada con la misma clave. No puede deshacer una generación que el proveedor haya procesado si la conexión termina con timeout; la app no hace reintentos automáticos de imágenes.

## Alcance técnico

Es una app personal, no un servicio multiusuario. No incluye pagos, conexión OAuth a Pinterest, scraping, publicación App Store, notificaciones push ni entrenamiento de modelos. La selección de fotos, permisos y firma nativa requieren la verificación final en el teléfono real. El sistema operativo puede cancelar una selección de fotos si cierra la actividad; en ese caso se puede volver a seleccionar la imagen.
