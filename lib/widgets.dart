import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'api.dart';

void notice(BuildContext context, Object message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$message')));
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String text, {
  String action = 'Continuar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: paper,
        title: Text(title, style: editorial(29)),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<Uint8List?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Una foto, mil posibilidades.', style: editorial(27)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de mis fotos'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 25 * 1024 * 1024) {
      throw ApiException('Elige una fotografía más pequeña.');
    }
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1280,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    final encoded = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    frame.image.dispose();
    codec.dispose();
    if (encoded == null || encoded.lengthInBytes > 8 * 1024 * 1024) {
      throw ApiException(
        'La foto es demasiado grande. Prueba con otra o recórtala.',
      );
    }
    return encoded.buffer.asUint8List();
  } catch (e) {
    if (context.mounted) {
      notice(
        context,
        e is ApiException ? e : 'No se pudo abrir la foto. Revisa los permisos de cámara o galería.',
      );
    }
    return null;
  }
}

class BusyButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;
  const BusyButton({
    super.key,
    required this.label,
    this.busy = false,
    this.onPressed,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: 9),
        ],
        Text(label),
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const Tag(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: .78),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: ink, height: 1.1),
    ),
  );
}

class PrivatePhoto extends StatelessWidget {
  final String? id;
  final BoxFit fit;
  const PrivatePhoto(this.id, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    if (id == null || !s.connected) return const PhotoPlaceholder();
    return Image.network(
      s.api.mediaUrl(id!),
      headers: s.api.headers,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const PhotoPlaceholder(),
      loadingBuilder: (_, child, event) => event == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
    );
  }
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFEFE7DF),
    child: const Center(
      child: Icon(Icons.image_outlined, color: muted, size: 30),
    ),
  );
}

class InspirationPhoto extends StatelessWidget {
  final Inspiration item;
  final BoxFit fit;
  const InspirationPhoto(this.item, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    if (item.imageId != null) return PrivatePhoto(item.imageId, fit: fit);
    Widget remote() => Image.network(
      item.imageUrl,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const PhotoPlaceholder(),
    );
    if (item.asset != null) {
      return Image.asset(
        item.asset!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => remote(),
      );
    }
    return remote();
  }
}

class SheetLayout extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SheetLayout({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: editorial(34)),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class EmptyMoment extends StatelessWidget {
  final String title, subtitle, button;
  final VoidCallback onPressed;
  final bool art;
  const EmptyMoment({
    super.key,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onPressed,
    this.art = true,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art) const HangerArt(),
          Text(title, style: editorial(36), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 25),
          BusyButton(label: button, onPressed: onPressed, icon: Icons.add),
        ],
      ),
    ),
  );
}

class LookCollage extends StatelessWidget {
  final Look look;
  final bool preview;
  const LookCollage(this.look, {super.key, this.preview = true});
  @override
  Widget build(BuildContext context) {
    if (preview && look.previewId != null) return PrivatePhoto(look.previewId);
    final items = context.watch<AppState>().clothesFor(look);
    if (items.isEmpty) return const PhotoPlaceholder();
    return Container(
      color: const Color(0xFFEDE5DD),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = items.length == 1 ? 1 : 2;
          final rows = (items.length / columns).ceil();
          return GridView.count(
            crossAxisCount: columns,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio:
                (box.maxWidth - (columns - 1) * 8) /
                columns /
                ((box.maxHeight - (rows - 1) * 8) / rows),
            children: items
                .map(
                  (g) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: PrivatePhoto(g.imageId, fit: BoxFit.contain),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
