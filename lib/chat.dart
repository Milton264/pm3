import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'settings.dart';
import 'looks.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  String? pending;
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> send([String? suggestion]) async {
    final s = context.read<AppState>();
    if (s.chatSending) return;
    final text = (suggestion ?? input.text).trim();
    if (text.isEmpty) return;
    if (!await ensureConnected(context) || !mounted) return;
    setState(() {
      pending = text;
      input.clear();
    });
    bottom();
    try {
      await s.sendMessage(text);
    } catch (e) {
      input.text = text;
      if (mounted) notice(context, e);
    } finally {
      if (mounted) {
        setState(() => pending = null);
        bottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>(),
        selected = context.watch<AppState>().lookById(
          context.watch<AppState>().chatLookId,
        );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 9, 18, 15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  color: blush,
                  shape: BoxShape.circle,
                ),
                child: const MuseMark(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entre tú y Musa.', style: editorial(29)),
                    const Text(
                      'Tu estilo. Una conversación.',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de conversación',
                onSelected: (v) async {
                  if (!await confirm(
                        context,
                        'Empezar de nuevo',
                        'Se eliminará esta conversación. Tus prendas, gustos y looks se conservarán.',
                        action: 'Borrar chat',
                      ) ||
                      !context.mounted) {
                    return;
                  }
                  try {
                    await s.clearChat();
                  } catch (e) {
                    if (context.mounted) notice(context, e);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'clear',
                    enabled: s.connected && !s.chatSending,
                    child: const Text('Borrar conversación'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (selected != null)
          Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            padding: const EdgeInsets.fromLTRB(13, 9, 4, 9),
            decoration: BoxDecoration(
              color: blush.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.checkroom_outlined, size: 19, color: plum),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Sobre: ${selected.title}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar contexto del look',
                  onPressed: s.chatSending ? null : s.clearChatContext,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        Expanded(
          child: s.messages.isEmpty && pending == null
              ? _welcome()
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(24, 5, 24, 20),
                  children: [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'UN POQUITO MÁS TÚ, EN CADA LOOK',
                          style: TextStyle(
                            fontSize: 8,
                            color: muted,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ),
                    for (final m in s.messages) ...[
                      _bubble(m.text, m.role == 'user'),
                      if (m.lookId != null &&
                          m.role == 'assistant' &&
                          s.lookById(m.lookId) != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20, right: 20),
                          child: GestureDetector(
                            onTap: () =>
                                openLook(context, s.lookById(m.lookId)!),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 73,
                                    height: 86,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LookCollage(s.lookById(m.lookId)!),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'TU NUEVA COMBINACIÓN',
                                          style: TextStyle(
                                            color: plum,
                                            fontSize: 8,
                                            letterSpacing: .7,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          s.lookById(m.lookId)!.title,
                                          style: editorial(22),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Ver el look ↗',
                                          style: TextStyle(
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
                        ),
                    ],
                    if (pending != null) _bubble(pending!, true),
                    if (s.chatSending)
                      const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 18),
                        child: Row(
                          children: [
                            MuseMark(size: 22),
                            SizedBox(width: 12),
                            SizedBox.square(
                              dimension: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Estoy pensando en tu look…',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: '¿Y si lo hacemos más… tú?',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 15,
                    ),
                  ),
                  onSubmitted: (_) => send(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox.square(
                dimension: 50,
                child: IconButton.filled(
                  tooltip: 'Enviar mensaje',
                  style: IconButton.styleFrom(backgroundColor: plum),
                  onPressed: s.chatSending ? null : send,
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _welcome() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(30, 38, 30, 20),
    child: Column(
      children: [
        const MuseMark(size: 75),
        const SizedBox(height: 28),
        Text(
          'No es solo ropa.\nEs cómo te sientes.',
          textAlign: TextAlign.center,
          style: editorial(37),
        ),
        const SizedBox(height: 19),
        const Text(
          'Cuéntame qué tienes en mente. Podemos cambiar una prenda, probar otra combinación o encontrar tu próximo favorito.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13, height: 1.65),
        ),
        const SizedBox(height: 27),
        for (final q in [
          'Quiero algo cómodo pero bonito',
          '¿Qué dice mi tablero sobre mi estilo?',
          'Ayúdame a combinar lo que ya tengo',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => send(q),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(q, style: const TextStyle(fontSize: 12)),
                    ),
                    const Icon(Icons.north_east, size: 15),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _bubble(String text, bool user) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .79,
      ),
      margin: const EdgeInsets.only(bottom: 18),
      padding: user
          ? const EdgeInsets.symmetric(horizontal: 17, vertical: 13)
          : const EdgeInsets.only(right: 9, top: 6),
      decoration: user
          ? const BoxDecoration(
              color: plum,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MuseMark(size: 15),
                SizedBox(width: 7),
                Text(
                  'MUSA',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: plum,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SelectableText(
            text,
            style: TextStyle(
              color: user ? Colors.white : ink,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
