import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'settings.dart';

Future<void> addGarment(BuildContext context) async {
  if (!await ensureConnected(context) || !context.mounted) return;
  final bytes = await pickPhoto(context);
  if (bytes == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GarmentEditor(bytes: bytes)),
  );
}

Future<void> addInspiration(BuildContext context) async {
  if (!await ensureConnected(context) || !context.mounted) return;
  final bytes = await pickPhoto(context);
  if (bytes == null || !context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => InspirationEditor(bytes: bytes),
  );
}

List<String> commaList(String value) => value
    .split(',')
    .map((v) => v.trim().toLowerCase())
    .where((v) => v.isNotEmpty)
    .toSet()
    .toList();

class GarmentEditor extends StatefulWidget {
  final Uint8List? bytes;
  final Garment? garment;
  const GarmentEditor({super.key, this.bytes, this.garment});
  @override
  State<GarmentEditor> createState() => _GarmentEditorState();
}

class _GarmentEditorState extends State<GarmentEditor> {
  final name = TextEditingController(),
      colors = TextEditingController(),
      tags = TextEditingController(),
      notes = TextEditingController();
  String category = 'top';
  bool analyzing = false, saving = false, available = true;
  String? analysisError;
  @override
  void initState() {
    super.initState();
    final g = widget.garment;
    if (g != null) {
      name.text = g.name;
      colors.text = g.colors.join(', ');
      tags.text = g.tags.join(', ');
      notes.text = g.notes;
      category = g.category;
      available = g.available;
    }
    if (widget.bytes != null) Future.microtask(analyze);
  }

  @override
  void dispose() {
    for (final c in [name, colors, tags, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> analyze() async {
    setState(() {
      analyzing = true;
      analysisError = null;
    });
    try {
      final data = await context.read<AppState>().analyze(widget.bytes!);
      if (!mounted) return;
      name.text = data['name'];
      colors.text = strings(data['colors']).join(', ');
      tags.text = strings(data['tags']).join(', ');
      notes.text = data['notes'] ?? '';
      setState(() => category = data['category']);
    } catch (e) {
      if (mounted) setState(() => analysisError = '$e');
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      notice(context, 'Ponle un nombre a esta prenda.');
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<AppState>().saveGarment(
        {
          'name': name.text.trim(),
          'category': category,
          'colors': commaList(colors.text),
          'tags': commaList(tags.text),
          'notes': notes.text.trim(),
          'available': available,
        },
        bytes: widget.bytes,
        id: widget.garment?.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.garment == null ? 'Una nueva posibilidad' : 'Mi prenda',
        style: const TextStyle(fontSize: 15),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
      children: [
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: const Color(0xFFF0EAE3),
              child: widget.bytes != null
                  ? Image.memory(widget.bytes!, fit: BoxFit.contain)
                  : PrivatePhoto(widget.garment!.imageId, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Conozcamos esta prenda.', style: editorial(32)),
        const SizedBox(height: 10),
        if (analyzing)
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Musa está mirando sus detalles…',
                    style: TextStyle(color: plum),
                  ),
                ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Revisa los detalles. Tú tienes la última palabra.',
              style: TextStyle(color: muted),
            ),
          ),
        if (analysisError != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: blush.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(analysisError!, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 5),
                const Text(
                  'Puedes completar los detalles manualmente.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                TextButton(
                  onPressed: analyze,
                  child: const Text('Volver a analizar'),
                ),
              ],
            ),
          ),
        TextField(
          controller: name,
          enabled: !analyzing,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nombre de la prenda',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: category,
          key: ValueKey(category),
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: categoryNames.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: analyzing
              ? null
              : (value) => setState(() => category = value!),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: colors,
          enabled: !analyzing,
          decoration: const InputDecoration(
            labelText: 'Colores',
            hintText: 'blanco, beige',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: tags,
          enabled: !analyzing,
          decoration: const InputDecoration(
            labelText: 'Estilo · separado por comas',
            hintText: 'casual, minimalista',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: notes,
          enabled: !analyzing,
          maxLines: 2,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Detalles que importan',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lista para usar'),
          subtitle: const Text(
            'Desactívala si está en la lavandería o no quieres usarla.',
            style: TextStyle(fontSize: 12),
          ),
          value: available,
          onChanged: (v) => setState(() => available = v),
        ),
        const SizedBox(height: 18),
        BusyButton(
          label: 'Guardar en mi armario',
          busy: saving,
          onPressed: analyzing ? null : save,
          icon: Icons.check,
        ),
        if (widget.garment != null)
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    if (!await confirm(
                          context,
                          'Quitar esta prenda',
                          'También se quitarán los looks que la incluyen.',
                          action: 'Quitar',
                        ) ||
                        !context.mounted) {
                      return;
                    }
                    try {
                      await context.read<AppState>().deleteGarment(
                        widget.garment!.id,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) notice(context, e);
                    }
                  },
            child: const Text('Eliminar prenda', style: TextStyle(color: red)),
          ),
      ],
    ),
  );
}

class InspirationEditor extends StatefulWidget {
  final Uint8List bytes;
  const InspirationEditor({super.key, required this.bytes});
  @override
  State<InspirationEditor> createState() => _InspirationEditorState();
}

class _InspirationEditorState extends State<InspirationEditor> {
  final title = TextEditingController(), tags = TextEditingController();
  bool busy = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      try {
        final j = await context.read<AppState>().analyze(
          widget.bytes,
          inspiration: true,
        );
        if (!mounted) return;
        title.text = j['title'];
        tags.text = strings(j['tags']).join(', ');
      } catch (e) {
        if (mounted) error = '$e';
      } finally {
        if (mounted) setState(() => busy = false);
      }
    });
  }

  @override
  void dispose() {
    title.dispose();
    tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetLayout(
    title: 'Eso que te inspira.',
    children: [
      SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(widget.bytes, fit: BoxFit.contain),
        ),
      ),
      const SizedBox(height: 20),
      if (busy)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '$error Puedes añadir el título y los estilos tú misma.',
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ),
      TextField(
        controller: title,
        enabled: !busy,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Un nombre para esta idea',
          counterText: '',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: tags,
        enabled: !busy,
        decoration: const InputDecoration(
          labelText: 'Estilos separados por comas',
          hintText: 'casual, denim, minimalista',
        ),
      ),
      const SizedBox(height: 20),
      BusyButton(
        label: 'Añadir a mis ideas',
        busy: saving,
        onPressed: busy
            ? null
            : () async {
                if (title.text.trim().isEmpty || commaList(tags.text).isEmpty) {
                  notice(context, 'Añade un título y al menos un estilo.');
                  return;
                }
                setState(() => saving = true);
                try {
                  await context.read<AppState>().addInspiration(
                    widget.bytes,
                    title.text.trim(),
                    commaList(tags.text),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) notice(context, e);
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
      ),
    ],
  );
}
