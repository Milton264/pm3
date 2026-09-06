import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'editors.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool board = false, favorites = false;
  final deckKey = GlobalKey<SwipeDeckState>();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pending = s.catalog.where((i) => !s.votes.containsKey(i.id)).toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('El estilo se siente.', style: editorial(37)),
                    const SizedBox(height: 7),
                    const Text(
                      'Menos reglas. Más de lo que te encanta.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Añadir una inspiración',
                onPressed: () => addInspiration(context),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 13),
          child: Row(
            children: [
              _ModePill(
                'Para ti',
                selected: !board,
                onTap: () => setState(() {
                  board = false;
                  favorites = false;
                }),
              ),
              const SizedBox(width: 7),
              _ModePill(
                'Mi tablero',
                selected: board,
                onTap: () => setState(() => board = true),
              ),
              const Spacer(),
              Text(
                MediaQuery.sizeOf(context).width < 360
                    ? '${s.taste.likes}'
                    : '${s.taste.likes} flechazos',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.favorite_border, size: 14, color: plum),
            ],
          ),
        ),
        Expanded(
          child: board
              ? _board(s)
              : pending.isEmpty
              ? _done(s)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SwipeDeck(
                    key: deckKey,
                    items: pending,
                    onVote: (item, liked) {
                      s.vote(item.id, liked);
                    },
                    onDetails: (item) => inspirationDetails(context, item),
                  ),
                ),
        ),
        if (!board && pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VoteButton(
                  icon: Icons.close_rounded,
                  label: 'Paso',
                  color: red,
                  fill: const Color(0xFFF5E9E6),
                  onPressed: () => deckKey.currentState?.decide(false),
                ),
                _VoteButton(
                  icon: Icons.undo_rounded,
                  label: 'Deshacer',
                  color: muted,
                  small: true,
                  onPressed: s.history.isEmpty ? null : () => s.undo(),
                ),
                _VoteButton(
                  icon: Icons.favorite_rounded,
                  label: 'Muy yo',
                  color: green,
                  fill: const Color(0xFFE5EDE3),
                  onPressed: () => deckKey.currentState?.decide(true),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 350) {
          return SingleChildScrollView(
            child: SizedBox(height: 500, child: content),
          );
        }
        return content;
      },
    );
  }

  Widget _done(AppState s) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 25, 28, 24),
    child: Column(
      children: [
        const MuseMark(size: 80),
        const SizedBox(height: 30),
        Text(
          'Tu estilo empieza\na hablar.',
          textAlign: TextAlign.center,
          style: editorial(42),
        ),
        const SizedBox(height: 18),
        Text(
          s.taste.favorites.isEmpty
              ? 'Todavía no hubo un flechazo. Puedes volver al tablero o añadir tus propias ideas.'
              : 'Hay algo de ti en cada elección. Estas son las pistas que llevaré a tu armario.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          alignment: WrapAlignment.center,
          children: s.taste.favorites.map((t) => Tag(t, color: blush)).toList(),
        ),
        const SizedBox(height: 32),
        BusyButton(
          label: 'Ahora, mi armario',
          icon: Icons.arrow_forward,
          onPressed: () => s.navigate(1),
        ),
        TextButton(
          onPressed: () => setState(() => board = true),
          child: const Text('Revisar mis elecciones'),
        ),
        TextButton(
          onPressed: () => addInspiration(context),
          child: const Text('Añadir más inspiración'),
        ),
      ],
    ),
  );
  Widget _board(AppState s) {
    final items = s.catalog
        .where((i) => !favorites || s.votes[i.id] == true)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      children: [
        Row(
          children: [
            const Text(
              'UN PEQUEÑO UNIVERSO TUYO',
              style: TextStyle(fontSize: 9, letterSpacing: 1.4, color: muted),
            ),
            const Spacer(),
            FilterChip(
              label: const Text('Me encantan'),
              selected: favorites,
              onSelected: (v) => setState(() => favorites = v),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 10,
                color: favorites ? Colors.white : muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Text(
              'Tus flechazos aparecerán aquí.',
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            2,
            (col) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: col == 1 ? 6 : 0,
                  right: col == 0 ? 6 : 0,
                ),
                child: Column(
                  children: [
                    for (var i = col; i < items.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 17),
                        child: GestureDetector(
                          onTap: () => inspirationDetails(context, items[i]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: i % 3 == 0 ? .7 : .83,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      InspirationPhoto(items[i]),
                                      if (s.votes.containsKey(items[i].id))
                                        Positioned(
                                          right: 9,
                                          top: 9,
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: const BoxDecoration(
                                              color: paper,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              s.votes[items[i].id]!
                                                  ? Icons.favorite
                                                  : Icons.close,
                                              size: 15,
                                              color: s.votes[items[i].id]!
                                                  ? green
                                                  : red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                items[i].title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                items[i].tags.take(2).join(' · '),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _ModePill(this.title, {required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(25),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? ink : Colors.transparent,
        border: Border.all(color: selected ? ink : line),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? paper : muted,
        ),
      ),
    ),
  );
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? fill;
  final bool small;
  final VoidCallback? onPressed;
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.color,
    this.fill,
    this.small = false,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox.square(
        dimension: small ? 45 : 62,
        child: IconButton.filled(
          tooltip: label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: fill ?? Colors.transparent,
            foregroundColor: color,
            disabledForegroundColor: line,
            side: BorderSide(color: fill == null ? line : Colors.transparent),
          ),
          icon: Icon(icon, size: small ? 22 : 27),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ],
  );
}

class SwipeDeck extends StatefulWidget {
  final List<Inspiration> items;
  final void Function(Inspiration, bool) onVote;
  final void Function(Inspiration) onDetails;
  const SwipeDeck({
    super.key,
    required this.items,
    required this.onVote,
    required this.onDetails,
  });
  @override
  State<SwipeDeck> createState() => SwipeDeckState();
}

class SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Offset offset = Offset.zero, start = Offset.zero, target = Offset.zero;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          if (mounted) {
            setState(
              () => offset = Offset.lerp(
                start,
                target,
                Curves.easeOutCubic.transform(controller.value),
              )!,
            );
          }
        });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> decide(bool liked) async {
    if (busy || widget.items.isEmpty) return;
    busy = true;
    final item = widget.items.first;
    HapticFeedback.lightImpact();
    start = offset;
    target = Offset(
      (liked ? 1 : -1) * (MediaQuery.sizeOf(context).width + 120),
      50,
    );
    try {
      await controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    widget.onVote(item, liked);
    setState(() {
      offset = Offset.zero;
      busy = false;
    });
  }

  Future<void> reset() async {
    busy = true;
    start = offset;
    target = Offset.zero;
    try {
      await controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.items.first;
    final amount = (offset.dx.abs() / 130).clamp(0.0, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.items.length > 1)
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 7),
              child: Transform.rotate(
                angle: -.025,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: InspirationPhoto(widget.items[1]),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            onPanStart: busy ? null : (_) => HapticFeedback.selectionClick(),
            onPanUpdate: (event) {
              if (!busy) {
                setState(
                  () => offset += Offset(event.delta.dx, event.delta.dy * .2),
                );
              }
            },
            onPanEnd: (event) {
              if (busy) return;
              if (offset.dx.abs() > 85 ||
                  event.velocity.pixelsPerSecond.dx.abs() > 800) {
                decide(
                  offset.dx == 0
                      ? event.velocity.pixelsPerSecond.dx > 0
                      : offset.dx > 0,
                );
              } else {
                reset();
              }
            },
            child: Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: offset.dx / 1600,
                child: Semantics(
                  label:
                      '${first.title}. Desliza a la derecha si te gusta, a la izquierda para descartar.',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        InspirationPhoto(first),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [.4, .68, 1],
                              colors: [
                                Colors.transparent,
                                Color(0x0D000000),
                                Color(0xA6000000),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 17,
                          left: 17,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: paper.withValues(alpha: .91),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MuseMark(size: 12),
                                SizedBox(width: 6),
                                Text(
                                  'UN POCO DE INSPIRACIÓN',
                                  style: TextStyle(
                                    fontSize: 8,
                                    letterSpacing: .9,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 21,
                          left: 20,
                          right: 17,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: first.tags
                                    .take(2)
                                    .map((t) => Tag(t))
                                    .toList(),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      first.title,
                                      style: editorial(32, color: Colors.white),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Ver idea y autor',
                                    onPressed: () => widget.onDetails(first),
                                    icon: const Icon(
                                      Icons.north_east_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'FOTO · ${first.author.toUpperCase()}',
                                style: const TextStyle(
                                  color: Color(0xFFEEE5DD),
                                  fontSize: 8,
                                  letterSpacing: .8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (amount > 0)
                          IgnorePointer(
                            child: Container(
                              color: (offset.dx >= 0 ? green : red).withValues(
                                alpha: amount * .32,
                              ),
                            ),
                          ),
                        if (amount > 0)
                          Positioned(
                            top: 90,
                            left: offset.dx >= 0 ? 22 : null,
                            right: offset.dx < 0 ? 22 : null,
                            child: Opacity(
                              opacity: amount,
                              child: Transform.rotate(
                                angle: offset.dx >= 0
                                    ? -math.pi / 12
                                    : math.pi / 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 19,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: paper,
                                    border: Border.all(
                                      color: offset.dx >= 0 ? green : red,
                                      width: 2.5,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    offset.dx >= 0 ? 'MUY YO' : 'PASO',
                                    style: TextStyle(
                                      color: offset.dx >= 0 ? green : red,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 28,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> inspirationDetails(BuildContext context, Inspiration item) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SheetLayout(
        title: item.title,
        children: [
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InspirationPhoto(item, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.tags.map((t) => Tag(t, color: blush)).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    c.read<AppState>().vote(item.id, false);
                    Navigator.pop(c);
                  },
                  icon: const Icon(Icons.close, color: red),
                  label: const Text('Paso'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    c.read<AppState>().vote(item.id, true);
                    Navigator.pop(c);
                  },
                  icon: const Icon(Icons.favorite, size: 18),
                  label: const Text('Muy yo'),
                ),
              ),
            ],
          ),
          if (item.source.isNotEmpty)
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(item.source),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.north_east, size: 15),
              label: Text(
                'Foto de ${item.author}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          if (item.imageId != null)
            TextButton(
              onPressed: () async {
                if (!await confirm(
                      c,
                      'Quitar esta idea',
                      'Se eliminarán esta referencia y tu elección sobre ella.',
                      action: 'Quitar',
                    ) ||
                    !c.mounted) {
                  return;
                }
                try {
                  await c.read<AppState>().deleteInspiration(item.id);
                  if (c.mounted) Navigator.pop(c);
                } catch (e) {
                  if (c.mounted) notice(c, e);
                }
              },
              child: const Text(
                'Eliminar esta idea',
                style: TextStyle(color: red),
              ),
            ),
        ],
      ),
    );
