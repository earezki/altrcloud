extension Unique<E, Id> on List<E> {
  List<E> unique([Id Function(E element)? id, bool inplace = true]) {
    final ids = Set();
    var list = inplace ? this : List<E>.from(this);
    list.retainWhere((x) => ids.add(id != null ? id(x) : x as Id));
    return list;
  }
}

extension AsyncListExtensions<T> on List<T> {
  Future<void> removeWhereAsync(Future<bool> Function(T) test) async {
    List<int> indicesToRemove = [];
    for (var i = 0; i < length; i++) {
      if (await test(elementAt(i))) {
        indicesToRemove.add(i);
      }
    }

    for (int idx in indicesToRemove) {
      removeAt(idx);
    }
  }
}
