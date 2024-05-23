Map<K, V> mergeMaps<K, V>(List<Map<K, V>> maps) {
  final mergedMap = <K, V>{};
  maps.forEach((map) {
    map.entries.forEach((entry) {
      mergedMap[entry.key] = entry.value;
    });
  });
  return mergedMap;
}