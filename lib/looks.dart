import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'settings.dart';

class LooksScreen extends StatefulWidget {
  const LooksScreen({super.key});
  @override
  State<LooksScreen> createState() => _LooksScreenState();
}

class _LooksScreenState extends State<LooksScreen> {
  String occasion = 'Día a día';
  bool savedOnly = false;
  Future<void> create() async {
    if (!await ensureConnected(context) || !mounted) return;
    final s = context.read<AppState>();
    if (!s.canRecommend) {
      notice(
        context,
        'Añade un vestido, o una prenda superior y una inferior, para empezar.',
      );
      s.navigate(1);
      return;
    }
    final notes = TextEditingController();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SheetLayout(
        title: 'Cuéntame un poquito.',
        children: [
          Text('El plan: $occasion', style: const TextStyle(color: plum)),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLines: 3,
            maxLength: 800,
            decoration: const InputDecoration(
              labelText: '¿Algo que deba tener en cuenta?',
              hintText:
                  'Hace calor, caminaré bastante, quiero usar mi bolso negro…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          BusyButton(
            label: 'Encontrar mi combinación',
            icon: Icons.auto_awesome_outlined,
            onPressed: () => Navigator.pop(c, notes.text.trim()),
          ),
        ],
      ),
    );
    notes.dispose();
    if (value == null || !mounted) return;
    try {
      await s.recommend(occasion, value);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.looks.where((l) => !savedOnly || l.saved).toList();
    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
        children: [
          Text('Un look.\nMuchas ganas de salir.', style: editorial(38)),
          const SizedBox(height: 12),
          const Text(
            'Con tu ropa, a tu manera.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: blush.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('¿Qué plan tienes?', style: editorial(29)),
                    ),
                    const MuseMark(size: 37),
                  ],
                ),
                const SizedBox(height: 17),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children:
                      [
                            'Día a día',
                            'Una cita',
                            'Oficina',
                            'Con amigas',
                            'Una salida',
                            'Evento',
                            'Viaje',
                          ]
                          .map(
                            (o) => ChoiceChip(
                              label: Text(o),
                              selected: o == occasion,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: o == occasion ? Colors.white : ink,
                              ),
                              onSelected: (_) => setState(() => occasion = o),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: BusyButton(
                    label: s.recommending
                        ? 'Musa está combinando…'
                        : 'Crear mis looks',
                    busy: s.recommending,
                    onPressed: create,
                    icon: Icons.auto_awesome_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 27),
          Row(
            children: [
              Expanded(child: Text('Tu colección', style: editorial(29))),
              FilterChip(
                label: const Text('Guardados'),
                selected: savedOnly,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: savedOnly ? Colors.white : muted,
                ),
                onSelected: (v) => setState(() => savedOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 17),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(27),
              decoration: BoxDecoration(
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.bookmark_border_rounded,
                    size: 33,
                    color: plum,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    savedOnly
                        ? 'Tus favoritos se quedan aquí.'
                        : 'Aquí empiezan los «me encanta».',
                    textAlign: TextAlign.center,
                    style: editorial(25),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    savedOnly ? 'Toca el marcador de un look para guardarlo.' : 'Elige un plan y deja que Musa conecte tus gustos con las prendas de tu armario.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          for (final look in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 23),
              child: LookCard(look),
            ),
        ],
      ),
    );
  }
}

class LookCard extends StatelessWidget {
  final Look look;
  const LookCard(this.look, {super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => openLook(context, look),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.05,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LookCollage(look),
                  Positioned(left: 13, top: 13, child: Tag(look.occasion)),
                  Positioned(
                    right: 9,
                    top: 9,
                    child: IconButton.filled(
                      tooltip: look.saved
                          ? 'Quitar de guardados'
                          : 'Guardar look',
                      style: IconButton.styleFrom(
                        backgroundColor: paper,
                        foregroundColor: plum,
                      ),
                      onPressed: () async {
                        try {
                          await context.read<AppState>().toggleSaved(look);
                        } catch (e) {
                          if (context.mounted) notice(context, e);
                        }
                      },
                      icon: Icon(
                        look.saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ),
                  ),
                  if (look.previewId != null)
                    const Positioned(
                      bottom: 12,
                      left: 12,
                      child: Tag('Vista previa generada'),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(look.title, style: editorial(27)),
                      const SizedBox(height: 6),
                      Text(
                        '${look.garmentIds.length} prendas de tu armario',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.north_east, size: 20, color: plum),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void openLook(BuildContext context, Look look) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => LookDetail(lookId: look.id)),
);

class LookDetail extends StatelessWidget {
  final String lookId;
  const LookDetail({super.key, required this.lookId});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final look = s.lookById(lookId);
    if (look == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Este look ya no está disponible.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'El look, en detalle',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            tooltip: look.saved ? 'Quitar de guardados' : 'Guardar look',
            onPressed: () async {
              try {
                await s.toggleSaved(look);
              } catch (e) {
                if (context.mounted) notice(context, e);
              }
            },
            icon: Icon(
              look.saved ? Icons.bookmark : Icons.bookmark_border,
              color: plum,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 5, 24, 32),
        children: [
          AspectRatio(
            aspectRatio: .9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: LookCollage(look),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            look.occasion.toUpperCase(),
            style: const TextStyle(
              color: plum,
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 9),
          Text(look.title, style: editorial(39)),
          const SizedBox(height: 17),
          Text(look.reason),
          if (look.styling.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: blush.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MuseMark(size: 25),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      look.styling,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          Text('Lo tienes en tu armario', style: editorial(28)),
          const SizedBox(height: 12),
          ...s
              .clothesFor(look)
              .map(
                (g) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        height: 70,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: PrivatePhoto(g.imageId, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              g.available
                                  ? g.colors.join(' · ')
                                  : 'Ahora está en pausa',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 24),
          BusyButton(
            label: 'Quiero cambiar algo',
            icon: Icons.chat_bubble_outline,
            onPressed: () {
              s.chatAbout(look);
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PreviewScreen(lookId: look.id)),
            ),
            icon: const Icon(Icons.auto_awesome_outlined, size: 19),
            label: const Text('Ver cómo se vería en mí'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              if (!await confirm(
                    context,
                    'Eliminar este look',
                    'Se eliminará también su vista previa. Tus prendas se conservarán.',
                    action: 'Eliminar',
                  ) ||
                  !context.mounted) {
                return;
              }
              try {
                await s.deleteLook(look.id);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) notice(context, e);
              }
            },
            child: const Text(
              'Eliminar look',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final String lookId;
  const PreviewScreen({super.key, required this.lookId});
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool busy = false, original = false, consent = false;
  final adjustment = TextEditingController();
  @override
  void dispose() {
    adjustment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final look = s.lookById(widget.lookId);
    if (look == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Este look ya no está disponible.')),
      );
    }
    final baseId = s.profile['bodyPhotoId'] as String?;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'El probador de Musa',
            style: TextStyle(fontSize: 15),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 5, 24, 30),
          children: [
            Text('Imagínate en él.', style: editorial(38)),
            const SizedBox(height: 11),
            Text(look.title, style: const TextStyle(color: muted)),
            const SizedBox(height: 22),
            if (look.previewId != null) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Mi foto original')),
                  ButtonSegment(value: false, label: Text('Con este look')),
                ],
                selected: {original},
                onSelectionChanged: (v) => setState(() => original = v.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 18),
            ],
            AspectRatio(
              aspectRatio: .73,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (baseId == null)
                      Container(
                        color: const Color(0xFFEFE8E0),
                        child: const Center(
                          child: Icon(
                            Icons.accessibility_new,
                            size: 100,
                            color: plum,
                          ),
                        ),
                      )
                    else
                      PrivatePhoto(
                        original || look.previewId == null
                            ? baseId
                            : look.previewId,
                        fit: BoxFit.contain,
                      ),
                    if (busy)
                      Container(
                        color: paper.withValues(alpha: .9),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MuseMark(size: 64),
                            SizedBox(height: 26),
                            CircularProgressIndicator(strokeWidth: 1.5),
                            SizedBox(height: 22),
                            Text(
                              'Tu look está tomando forma.',
                              style: TextStyle(color: plum),
                            ),
                            SizedBox(height: 9),
                            Text(
                              'Puede tardar un par de minutos.',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 14,
                      bottom: 14,
                      child: Tag(
                        original || look.previewId == null
                            ? 'Foto original'
                            : 'Vista previa · imagen generada',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Una idea de cómo se vería. Los detalles, la identidad y el ajuste pueden variar en la imagen generada.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            if (baseId == null)
              BusyButton(
                label: 'Añadir mi foto de cuerpo completo',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: () => openSettings(context),
              )
            else if (!s.previewEnabled)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: blush.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Casi listo para probar.', style: editorial(27)),
                    const SizedBox(height: 10),
                    const Text(
                      'Para generar esta imagen falta activar Gemini en tu espacio. Tus looks y el chat con Musa ya pueden usarse.',
                      style: TextStyle(fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () => openSettings(context),
                      child: const Text('Ver configuración'),
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: adjustment,
                enabled: !busy,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Un detalle para la vista previa',
                  hintText: 'La camisa por dentro, mangas remangadas…',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Permito enviar mi foto y estas prendas a Gemini para crear la vista previa.',
                  style: TextStyle(fontSize: 12),
                ),
                subtitle: const Text(
                  'La generación puede consumir saldo de la cuenta configurada.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                onChanged: busy
                    ? null
                    : (v) => setState(() => consent = v ?? false),
              ),
              const SizedBox(height: 16),
              BusyButton(
                label: look.previewId == null
                    ? 'Crear mi vista previa'
                    : 'Generar otra versión',
                busy: busy,
                icon: Icons.auto_awesome_outlined,
                onPressed: consent
                    ? () async {
                        setState(() => busy = true);
                        try {
                          await s.preview(look, adjustment.text.trim());
                          if (mounted) setState(() => original = false);
                        } catch (e) {
                          if (context.mounted) notice(context, e);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
