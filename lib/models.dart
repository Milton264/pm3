import 'dart:convert';

typedef Json = Map<String, dynamic>;
List<String> strings(dynamic value) =>
    (value as List? ?? []).map((v) => '$v').toList();
Json object(dynamic value) => Map<String, dynamic>.from(value as Map);

class Inspiration {
  final String id, title, imageUrl, author, source;
  final String? asset, imageId;
  final List<String> tags;
  Inspiration.fromJson(Json j)
    : id = j['id'],
      title = j['title'],
      imageUrl = j['imageUrl'] ?? '',
      author = j['author'] ?? 'Tu inspiración',
      source = j['source'] ?? '',
      asset = j['asset'],
      imageId = j['imageId'],
      tags = strings(j['tags']);
}

const categoryNames = {
  'top': 'Partes de arriba',
  'bottom': 'Partes de abajo',
  'dress': 'Vestidos',
  'outerwear': 'Capas',
  'shoes': 'Zapatos',
  'bag': 'Bolsos',
  'accessory': 'Accesorios',
};

class Garment {
  final String id, name, category, imageId, notes;
  final List<String> colors, tags;
  final bool available;
  Garment.fromJson(Json j)
    : id = j['id'],
      name = j['name'],
      category = j['category'],
      imageId = j['imageId'],
      colors = strings(j['colors']),
      tags = strings(j['tags']),
      notes = j['notes'] ?? '',
      available = j['available'] ?? true;
  Json toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'imageId': imageId,
    'colors': colors,
    'tags': tags,
    'notes': notes,
    'available': available,
  };
}

class Look {
  final String id, title, reason, styling, occasion;
  final String? previewId;
  final bool saved;
  final List<String> garmentIds;
  Look.fromJson(Json j)
    : id = j['id'],
      title = j['title'],
      reason = j['reason'],
      styling = j['styling'] ?? '',
      occasion = j['occasion'] ?? '',
      previewId = j['previewId'],
      saved = j['saved'] ?? false,
      garmentIds = strings(j['garmentIds']);
}

class ChatMessage {
  final String id, text, role;
  final String? lookId;
  ChatMessage.fromJson(Json j)
    : id = j['id'],
      text = j['text'],
      role = j['role'],
      lookId = j['lookId'];
}

class Taste {
  final Map<String, double> scores;
  final int reviewed, likes;
  Taste(List<Inspiration> catalog, Map<String, bool> votes)
    : reviewed = votes.length,
      likes = votes.values.where((v) => v).length,
      scores = _calculate(catalog, votes);
  static Map<String, double> _calculate(
    List<Inspiration> catalog,
    Map<String, bool> votes,
  ) {
    final totals = <String, int>{}, seen = <String, int>{};
    for (final item in catalog) {
      if (!votes.containsKey(item.id)) continue;
      for (final tag in item.tags) {
        totals[tag] = (totals[tag] ?? 0) + (votes[item.id]! ? 1 : -1);
        seen[tag] = (seen[tag] ?? 0) + 1;
      }
    }
    return totals.map((tag, score) => MapEntry(tag, score / (seen[tag]! + 2)));
  }

  List<String> get favorites {
    final list = scores.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).map((e) => e.key).toList();
  }
}

Json parseObject(String text) => object(jsonDecode(text));
