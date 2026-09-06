import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'editors.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String category = 'all', query = '';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.garments
        .where(
          (g) =>
              (category == 'all' || category == g.category) &&
              '${g.name} ${g.colors.join(' ')} ${g.tags.join(' ')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: s.refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tu armario,\nredescubierto.',
                          style: editorial(38),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Añadir prenda',
                        onPressed: () => addGarment(context),
                        style: IconButton.styleFrom(backgroundColor: plum),
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.garments.isEmpty
                        ? 'Todo empieza con lo que ya tienes.'
                        : '${s.garments.length} prendas · infinitas formas de ser tú',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 23),
                  if (s.garments.isNotEmpty) ...[
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        hintText: 'Busca una prenda, un color…',
                        prefixIcon: Icon(Icons.search, size: 21),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final entry in {
                            'all': 'Todo',
                            ...categoryNames,
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(entry.value),
                                selected: category == entry.key,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: category == entry.key
                                      ? Colors.white
                                      : ink,
                                ),
                                onSelected: (_) =>
                                    setState(() => category = entry.key),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ),
          if (s.garments.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyMoment(
                title: 'Seguro tienes\nalgo increíble.',
                subtitle: 'Fotografía tus prendas. Musa reconocerá sus detalles y descubrirá nuevas formas de combinarlas.',
                button: 'Añadir mi primera prenda',
                onPressed: () => addGarment(context),
              ),
            )
          else if (items.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No encontré prendas con ese filtro.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 25),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .67,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 20,
                ),
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final g = items[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GarmentEditor(garment: g),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color: const Color(0xFFF0EAE3),
                                  child: PrivatePhoto(
                                    g.imageId,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                if (!g.available)
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: Tag(
                                      'En pausa',
                                      color: paper.withValues(alpha: .9),
                                    ),
                                  ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: paper,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.north_east,
                                      size: 13,
                                      color: plum,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          g.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          g.colors.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
