dynamic sanitizeJsonValue(dynamic v) {
  if (v == null) return null;

  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  if (v is List) {
    final cleaned = v
        .map(sanitizeJsonValue)
        .where((e) => e != null)
        .toList();
    return cleaned.isEmpty ? null : cleaned;
  }

  if (v is Map) {
    final cleaned = <String, dynamic>{};
    v.forEach((key, value) {
      final sv = sanitizeJsonValue(value);
      if (sv != null) cleaned[key.toString()] = sv;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  // num/bool/DateTime/Timestamp 등은 그대로
  return v;
}

Map<String, dynamic> sanitizeMap(Map<String, dynamic> input) {
  final cleaned = sanitizeJsonValue(input);
  return (cleaned is Map<String, dynamic>) ? cleaned : <String, dynamic>{};
}