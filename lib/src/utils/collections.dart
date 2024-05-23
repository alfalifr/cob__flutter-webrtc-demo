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
}