extension CollectionExt<T> on List<T> {

  T? find(bool Function(T) predicate) {
    for(final e in this) {
      if(predicate(e)) {
        return e;
      }
    }
    return null;
  }

  bool any(bool Function(T) predicate) {
    for(final e in this) {
      if(predicate(e)) {
        return true;
      }
    }
    return false;
  }

  bool all(bool Function(T) predicate) {
    for(final e in this) {
      if(!predicate(e)) {
        return false;
      }
    }
    return true;
  }

  bool addIfAll(T e, bool Function(T) predicate) {
    if(all(predicate)) {
      add(e);
      return true;
    }
    return false;
  }
}