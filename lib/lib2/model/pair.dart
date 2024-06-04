class Pair<T1, T2> {
  final T1 first;
  final T2 second;
  Pair(
    this.first,
    this.second,
  );

  @override
  bool operator ==(Object other) =>
      other is Pair &&
      other.first == first &&
      other.second == second;

  @override
  int get hashCode => first.hashCode + second.hashCode;

}