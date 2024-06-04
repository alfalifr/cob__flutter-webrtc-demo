import '../../lib2/model/pair.dart';

class Math {
  /// It can describe how many handshake in a group.
  /// Each person must handshake with the other same person exactly once.
  Map<T, List<T>> getFactorialPairMap<T>(List<T> list) {
    final pairMap = <T, List<T>>{};
    for(var i = 0; i < list.length; i++) {
      for(var u = i+1; u < list.length; u++) {
        (pairMap[list[i]] ??= []).add(list[u]);
      }
    }
    return pairMap;
  }
}