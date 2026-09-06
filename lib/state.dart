import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final MusaApi api;
  final FlutterSecureStorage secure;
  SharedPreferences? prefs;
  AppState({MusaApi? api, FlutterSecureStorage? secure})
    : api = api ?? MusaApi(),
      secure =
          secure ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  List<Inspiration> baseCatalog = [], customCatalog = [];
  List<Garment> garments = [];
  List<Look> looks = [];
  List<ChatMessage> messages = [];
  Map<String, bool> votes = {};
  Map<String, bool?> pendingVotes = {};
  Json profile = {'name': '', 'notes': '', 'bodyPhotoId': null};
  bool ready = false,
      loading = false,
      chatSending = false,
      recommending = false,
      previewEnabled = false;
  String? syncError, chatLookId;
  int tab = 0;
  final List<({String id, bool? previous})> history = [];
  Future<void> _voteQueue = Future.value();
  List<Inspiration> get catalog => [...baseCatalog, ...customCatalog];
  Taste get taste => Taste(catalog, votes);
  bool get connected => api.connected;
  bool get canRecommend =>
      garments.any((g) => g.available && g.category == 'dress') ||
      (garments.any((g) => g.available && g.category == 'top') &&
          garments.any((g) => g.available && g.category == 'bottom'));
  List<Garment> clothesFor(Look look) => look.garmentIds
      .map((id) => garments.where((g) => g.id == id).firstOrNull)
      .whereType<Garment>()
      .toList();
  Look? lookById(String? id) => looks.where((l) => l.id == id).firstOrNull;
  void navigate(int value) {
    tab = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    baseCatalog = (jsonDecode(
      await rootBundle.loadString('assets/catalog.json'),
    ) as List).map((j) => Inspiration.fromJson(object(j))).toList();
    prefs = await SharedPreferences.getInstance();
    try {
      final saved = parseObject(prefs!.getString('musa.votes') ?? '{}');
      votes = Map<String, bool>.from(saved['votes'] ?? {});
      pendingVotes = Map<String, bool?>.from(saved['pending'] ?? {});
      final session = await secure.read(key: 'musa.session');
      if (session != null) {
        final j = parseObject(session);
        api.baseUrl = j['baseUrl'];
        api.token = j['token'];
      }
      api.baseUrl = api.baseUrl.isEmpty
          ? const String.fromEnvironment('API_BASE_URL')
          : api.baseUrl;
    } catch (_) {
      syncError = 'No se pudo recuperar la sesión guardada. Puedes volver a conectar tu espacio.';
    }
    ready = true;
    notifyListeners();
    if (connected) {
      try {
        await refresh();
      } catch (error) {
        syncError = '$error';
        notifyListeners();
      }
    }
  }

  Future<void> connect(String url, String code) async {
    final previousUrl = api.baseUrl, previousToken = api.token;
    api.baseUrl = MusaApi.normalizeUrl(url);
    api.token = '';
    try {
      final response = await api.request(
        'POST',
        '/v1/session',
        data: {'code': code.trim()},
      );
      api.token = response['token'];
      await refresh();
      await secure.write(
        key: 'musa.session',
        value: jsonEncode({'baseUrl': api.baseUrl, 'token': api.token}),
      );
    } catch (_) {
      api.baseUrl = previousUrl;
      api.token = previousToken;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> disconnect({bool revoke = true}) async {
    if (connected && revoke) {
      try {
        await api.request('DELETE', '/v1/session');
      } catch (_) {}
    }
    await secure.delete(key: 'musa.session');
    api.token = '';
    garments = [];
    looks = [];
    messages = [];
    customCatalog = [];
    profile = {'name': '', 'notes': '', 'bodyPhotoId': null};
    previewEnabled = false;
    chatLookId = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!connected) return;
    loading = true;
    notifyListeners();
    try {
      final j = await api.request('GET', '/v1/bootstrap');
      garments = (j['garments'] as List)
          .map((g) => Garment.fromJson(object(g)))
          .toList();
      looks = (j['looks'] as List)
          .map((g) => Look.fromJson(object(g)))
          .toList();
      messages = (j['messages'] as List)
          .map((g) => ChatMessage.fromJson(object(g)))
          .toList();
      customCatalog = (j['inspirations'] as List)
          .map((g) => Inspiration.fromJson(object(g)))
          .toList();
      profile = object(j['profile']);
      previewEnabled = j['capabilities']['preview'] == true;
      votes = Map<String, bool>.from(j['votes']);
      for (final e in pendingVotes.entries) {
        if (e.value == null) {
          votes.remove(e.key);
        } else {
          votes[e.key] = e.value!;
        }
      }
      syncError = null;
      await _saveVotes();
      try {
        await syncVotes();
      } catch (error) {
        syncError = '$error';
      }
    } on ApiException catch (error) {
      syncError = error.message;
      if (error.status == 401) await disconnect(revoke: false);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveVotes() async => prefs?.setString(
    'musa.votes',
    jsonEncode({'votes': votes, 'pending': pendingVotes}),
  );
  Future<void> vote(String id, bool liked) async {
    history.add((id: id, previous: votes[id]));
    votes[id] = liked;
    pendingVotes[id] = liked;
    notifyListeners();
    await _queueVotes();
  }

  Future<void> undo() async {
    if (history.isEmpty) return;
    final change = history.removeLast();
    if (change.previous == null) {
      votes.remove(change.id);
    } else {
      votes[change.id] = change.previous!;
    }
    pendingVotes[change.id] = change.previous;
    notifyListeners();
    await _queueVotes();
  }

  Future<void> _queueVotes() {
    _voteQueue = _voteQueue.then((_) async {
      await _saveVotes();
      try {
        await syncVotes();
      } catch (e) {
        syncError = '$e';
        notifyListeners();
      }
    });
    return _voteQueue;
  }

  Future<void> syncVotes() async {
    if (!connected || pendingVotes.isEmpty) return;
    final snapshot = Map<String, bool?>.from(pendingVotes);
    // A custom reference removed on another device must not block every later vote.
    snapshot.removeWhere((k, v) => !catalog.any((i) => i.id == k));
    if (snapshot.isNotEmpty) {
      await api.request('PUT', '/v1/votes', data: {'votes': snapshot});
    }
    for (final e in snapshot.entries) {
      if (pendingVotes[e.key] == e.value) pendingVotes.remove(e.key);
    }
    pendingVotes.removeWhere((k, v) => !catalog.any((i) => i.id == k));
    syncError = null;
    await _saveVotes();
    notifyListeners();
  }

  Json photo(Uint8List bytes) => {'data': base64Encode(bytes)};
  Future<Json> analyze(Uint8List bytes, {bool inspiration = false}) =>
      api.request(
        'POST',
        '/v1/analyze',
        data: {
          'image': photo(bytes),
          'kind': inspiration ? 'inspiration' : 'garment',
        },
      );
  Future<void> saveGarment(Json fields, {Uint8List? bytes, String? id}) async {
    await api.request(
      id == null ? 'POST' : 'PUT',
      '/v1/garments${id == null ? '' : '/$id'}',
      data: {...fields, if (bytes != null) 'image': photo(bytes)},
    );
    await refresh();
  }

  Future<void> deleteGarment(String id) async {
    await api.request('DELETE', '/v1/garments/$id');
    await refresh();
  }

  Future<void> addInspiration(
    Uint8List bytes,
    String title,
    List<String> tags,
  ) async {
    await api.request(
      'POST',
      '/v1/inspirations',
      data: {'image': photo(bytes), 'title': title, 'tags': tags},
    );
    await refresh();
  }

  Future<void> deleteInspiration(String id) async {
    await api.request('DELETE', '/v1/inspirations/$id');
    pendingVotes.remove(id);
    votes.remove(id);
    await _saveVotes();
    await refresh();
  }

  Future<void> saveProfile(String name, String notes) async {
    profile = await api.request(
      'PUT',
      '/v1/profile',
      data: {'name': name, 'notes': notes},
    );
    notifyListeners();
  }

  Future<void> saveBody(Uint8List bytes) async {
    profile = await api.request(
      'PUT',
      '/v1/body-photo',
      data: {'image': photo(bytes), 'consent': true},
    );
    notifyListeners();
  }

  Future<void> deleteBody() async {
    await api.request('DELETE', '/v1/body-photo');
    await refresh();
  }

  Future<void> recommend(String occasion, String notes) async {
    if (recommending) return;
    recommending = true;
    notifyListeners();
    try {
      await syncVotes();
      await api.request(
        'POST',
        '/v1/recommendations',
        data: {'occasion': occasion, 'notes': notes},
        idempotent: true,
      );
      await refresh();
    } finally {
      recommending = false;
      notifyListeners();
    }
  }

  Future<void> toggleSaved(Look look) async {
    final j = await api.request(
      'PUT',
      '/v1/looks/${look.id}',
      data: {'saved': !look.saved},
    );
    looks = looks.map((l) => l.id == look.id ? Look.fromJson(j) : l).toList();
    notifyListeners();
  }

  Future<void> deleteLook(String id) async {
    await api.request('DELETE', '/v1/looks/$id');
    if (chatLookId == id) chatLookId = null;
    await refresh();
  }

  void chatAbout(Look look) {
    chatLookId = look.id;
    tab = 3;
    notifyListeners();
  }

  void clearChatContext() {
    chatLookId = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (chatSending) return;
    chatSending = true;
    notifyListeners();
    try {
      await syncVotes();
      final j = await api.request(
        'POST',
        '/v1/chat',
        data: {'message': text, if (chatLookId != null) 'lookId': chatLookId},
        idempotent: true,
      );
      messages.addAll(
        (j['messages'] as List).map((m) => ChatMessage.fromJson(object(m))),
      );
      if (j['look'] != null) {
        final l = Look.fromJson(object(j['look']));
        looks.insert(0, l);
        chatLookId = l.id;
      }
    } finally {
      chatSending = false;
      notifyListeners();
    }
  }

  Future<void> clearChat() async {
    await api.request('DELETE', '/v1/chat');
    messages = [];
    chatLookId = null;
    notifyListeners();
  }

  Future<Look> preview(Look look, String adjustment) async {
    final j = await api.request(
      'POST',
      '/v1/previews',
      data: {'lookId': look.id, 'adjustment': adjustment, 'consent': true},
      idempotent: true,
      timeout: const Duration(seconds: 205),
    );
    final updated = Look.fromJson(object(j['look']));
    looks = looks.map((l) => l.id == look.id ? updated : l).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deleteAll() async {
    await api.request('DELETE', '/v1/data', data: {'confirm': 'BORRAR'});
    votes.clear();
    pendingVotes.clear();
    history.clear();
    await _saveVotes();
    await disconnect(revoke: false);
  }
}
