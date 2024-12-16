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
    List<T> toRemove = [];

    for (final o in this) {
      if (await test(o)) {
        toRemove.add(o);
      }
    }

    for (final o in toRemove) {
      remove(o);
    }
  }
}

int sum(Iterable<int> ints) {
  var result = 0;
  for (final value in ints) {
    result += value;
  }
  return result;
}

List<List<T>> partition<T>(List<T> list, int size) {
  List<List<T>> partitions = [];
  List<T> currPartition = [];
  for (final e in list) {
    currPartition.add(e);
    if (currPartition.length == size) {
      partitions.add(currPartition);
      currPartition = [];
    }
  }

  if (currPartition.isNotEmpty) {
    partitions.add(currPartition);
  }

  return partitions;
}

// returns unique, duplicates
(Set<T>, List<T>) getDuplicates<T>(
    List<T> list, String Function(T c) keyExtractor) {
  Set<String> uniqueKeys = {};
  List<T> duplicates = [];
  Set<T> unique = {};
  for (final e in list) {
    final id = keyExtractor(e);
    if (uniqueKeys.contains(id)) {
      duplicates.add(e);
    } else {
      uniqueKeys.add(id);
      unique.add(e);
    }
  }

  return (unique, duplicates);
}
