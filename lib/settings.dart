import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<bool> ensureConnected(BuildContext context) async {
  if (context.read<AppState>().connected) return true;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ConnectSheet(),
  );
  return context.mounted && context.read<AppState>().connected;
}

void openSettings(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const SettingsScreen()),
);

class ConnectSheet extends StatefulWidget {
  const ConnectSheet({super.key});
  @override
  State<ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<ConnectSheet> {
  final url = TextEditingController(), code = TextEditingController();
  bool busy = false, visible = false;
  String? error;
  @override
  void initState() {
    super.initState();
    url.text = context.read<AppState>().api.baseUrl;
  }

  @override
  void dispose() {
    url.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppState>().connect(url.text, code.text);
      if (mounted) {
        Navigator.pop(context);
        notice(context, 'Tu espacio está listo.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetLayout(
    title: 'Tu espacio privado.',
    children: [
      const Text(
        'Conecta Musa una vez para guardar tu armario y hablar con tu estilista.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: url,
        autocorrect: false,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Dirección de tu espacio',
          hintText: 'https://musa.tudominio.com',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: code,
        obscureText: !visible,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => busy ? null : connect(),
        decoration: InputDecoration(
          labelText: 'Código de acceso',
          suffixIcon: IconButton(
            tooltip: visible ? 'Ocultar código' : 'Mostrar código',
            onPressed: () => setState(() => visible = !visible),
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 14),
        Text(error!, style: const TextStyle(color: red)),
      ],
      const SizedBox(height: 24),
      BusyButton(label: 'Entrar a mi espacio', busy: busy, onPressed: connect),
      const SizedBox(height: 14),
      const Text(
        'La dirección y el código están en la configuración que preparó Milton para ti.',
        style: TextStyle(color: muted, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController name, notes;
  bool saving = false, photoBusy = false;
  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    name = TextEditingController(text: p['name']);
    notes = TextEditingController(text: p['notes']);
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final s = context.read<AppState>();
    setState(() => saving = true);
    try {
      await s.saveProfile(name.text.trim(), notes.text.trim());
      if (mounted) notice(context, 'Musa lo tendrá en cuenta.');
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> uploadBody() async {
    if (!await ensureConnected(context) || !mounted) return;
    if (!await confirm(
          context,
          'La foto de la que partimos.',
          'Elige una foto tuya de cuerpo completo, con ropa y buena luz. Se guardará en tu espacio privado. Al generar una vista previa te pediré permiso para enviarla al servicio de imágenes.',
          action: 'Elegir mi foto',
        ) ||
        !mounted) {
      return;
    }
    final bytes = await pickPhoto(context);
    if (bytes == null || !mounted) return;
    setState(() => photoBusy = true);
    try {
      await context.read<AppState>().saveBody(bytes);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Future<void> erase() async {
    final field = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: paper,
        title: Text('Borrar mi espacio', style: editorial(29)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se eliminarán tus prendas, gustos, fotos, looks y conversaciones. Escribe BORRAR para confirmar.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: field,
              decoration: const InputDecoration(labelText: 'Confirmación'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (field.text == 'BORRAR') Navigator.pop(c, true);
            },
            child: const Text('Borrar todo', style: TextStyle(color: red)),
          ),
        ],
      ),
    );
    field.dispose();
    if (approved != true || !mounted) return;
    try {
      await context.read<AppState>().deleteAll();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi espacio', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          const Center(child: MuseMark(size: 58)),
          const SizedBox(height: 20),
          Center(child: Text('Tan única como tú.', style: editorial(36))),
          const SizedBox(height: 12),
          const Text(
            'Un armario que te entiende un poquito más cada día.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 32),
          if (!s.connected) ...[
            BusyButton(
              label: 'Conectar mi espacio',
              icon: Icons.lock_outline,
              onPressed: () async {
                await ensureConnected(context);
                if (mounted) {
                  name.text = s.profile['name'];
                  notes.text = s.profile['notes'];
                }
              },
            ),
            const SizedBox(height: 28),
          ],
          Text('Lo que te hace tú', style: editorial(29)),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: '¿Cómo te llamas?',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notes,
            maxLines: 3,
            maxLength: 1200,
            decoration: const InputDecoration(
              labelText: 'Lo que Musa debería saber',
              hintText:
                  'Prefiero zapatos bajos, me gustan las prendas sueltas…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          BusyButton(
            label: 'Guardar mis preferencias',
            busy: saving,
            onPressed: s.connected ? save : null,
          ),
          const SizedBox(height: 34),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Mi foto base', style: editorial(30))),
              const Icon(Icons.lock_outline, size: 18, color: muted),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Cada vista previa empieza con esta foto original. Puedes reemplazarla o eliminarla cuando quieras.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 18),
          if (s.profile['bodyPhotoId'] != null)
            Center(
              child: SizedBox(
                width: 230,
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: PrivatePhoto(
                    s.profile['bodyPhotoId'],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE8E0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.accessibility_new_rounded, size: 72, color: plum),
                  SizedBox(height: 14),
                  Text('Tú, de pies a cabeza', style: TextStyle(color: muted)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          BusyButton(
            label: s.profile['bodyPhotoId'] == null
                ? 'Añadir mi foto'
                : 'Cambiar mi foto',
            busy: photoBusy,
            onPressed: uploadBody,
            icon: Icons.add_photo_alternate_outlined,
          ),
          if (s.profile['bodyPhotoId'] != null)
            TextButton(
              onPressed: () async {
                if (!await confirm(
                      context,
                      'Eliminar mi foto',
                      'También se eliminarán las vistas previas generadas.',
                      action: 'Eliminar',
                    ) ||
                    !mounted) {
                  return;
                }
                try {
                  await s.deleteBody();
                } catch (e) {
                  if (context.mounted) notice(context, e);
                }
              },
              child: const Text(
                'Eliminar foto y vistas previas',
                style: TextStyle(color: red),
              ),
            ),
          const SizedBox(height: 24),
          if (s.connected)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.previewEnabled
                        ? 'El probador está habilitado'
                        : 'Activar el probador visual',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    s.previewEnabled
                        ? 'Una aproximación creativa de cómo se vería un look; el ajuste real de la ropa puede variar.'
                        : 'La conversación y el análisis usan Groq. Para crear imágenes, Milton debe añadir la clave de Gemini al servidor. La generación puede tener un costo.',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 26),
          Text('Tu estilo, hasta ahora', style: editorial(29)),
          const SizedBox(height: 12),
          Text(
            '${s.taste.reviewed} referencias vistas · ${s.taste.likes} que te encantan',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: s.taste.favorites
                .map((t) => Tag(t, color: blush))
                .toList(),
          ),
          const SizedBox(height: 28),
          const Divider(),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Sobre las fotografías'),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'La colección inicial incluye fotografías de Unsplash. Las referencias que añadas son privadas. Musa no extrae contenido de Pinterest.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
              ...s.baseCatalog.map(
                (i) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.title),
                  subtitle: Text(i.author),
                  trailing: const Icon(Icons.north_east, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(i.source),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
          if (s.connected) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync),
              title: const Text('Sincronizar mi espacio'),
              onTap: () async {
                try {
                  await s.refresh();
                  if (context.mounted) notice(context, 'Todo está al día.');
                } catch (e) {
                  if (context.mounted) notice(context, e);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión en este dispositivo'),
              onTap: () async {
                await s.disconnect();
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: red),
              title: const Text(
                'Borrar todos mis datos',
                style: TextStyle(color: red),
              ),
              onTap: erase,
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text('musa', style: editorial(36, color: plum)),
          ),
          const Center(
            child: Text(
              'Hecha con cariño, para ti.  ·  1.0.0',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
