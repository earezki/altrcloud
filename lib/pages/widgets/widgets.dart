import 'package:flutter/material.dart';

Widget getUsedSizeWidget(int sizeInBytes) {
  return Text(getUserSizeString(sizeInBytes));
}

String getUserSizeString(int sizeInBytes) {
  final int usedBytes = sizeInBytes;
  final double usedInMB = usedBytes / 1024 / 1024;
  final double usedInGB = usedInMB / 1024;

  return usedInGB.truncate() != 0
      ? '${usedInGB.toStringAsFixed(1)} GB'
      : '${usedInMB.toStringAsFixed(1)} MB';
}
