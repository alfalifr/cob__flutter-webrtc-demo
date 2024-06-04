Map<K, V> mergeMaps<K, V>(List<Map<K, V>> maps) {
  final mergedMap = <K, V>{};
  maps.forEach((map) {
    map.entries.forEach((entry) {
      mergedMap[entry.key] = entry.value;
    });
  });
  return mergedMap;
}

extension MapOfList<K, V> on Map<K, List<V>> {
  List<V> get flattenedValues {
    final result = <V>[];
    values.forEach((eList) {
      eList.forEach((e) => result.add(e));
    });
    return result;
  }

  int get flattenedValueLength =>
      values.fold(0, (totalLen, list) => totalLen + list.length);
}