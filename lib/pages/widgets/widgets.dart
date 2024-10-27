import 'package:flutter/material.dart';

typedef TextPredicate = bool Function(String txt);

Widget getUsedSizeWidget(int sizeInBytes) {
  return Text(getUsedSizeString(sizeInBytes));
}

String getUsedSizeString(int sizeInBytes) {
  final int usedBytes = sizeInBytes;
  final double usedInMB = usedBytes / 1024 / 1024;
  final double usedInGB = usedInMB / 1024;

  return usedInGB.truncate() != 0
      ? '${usedInGB.toStringAsFixed(1)} GB'
      : '${usedInMB.toStringAsFixed(1)} MB';
}

Widget halfSizedCircularProgress() {
  return scaledCircularProgress(0.5);
}

Widget scaledCircularProgress(double scale) {
  return Transform.scale(
    scale: scale,
    child: const CircularProgressIndicator(),
  );
}

void showConfirmationDialog(BuildContext context, VoidCallback onPressed,
    {String message = 'Are you sure you want to proceed?'}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onPressed();
            },
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
}

Future<void> displayTextInputDialog(
  BuildContext context,
  TextEditingController controller, {
  required String title,
  required String error,
  required TextPredicate isValid,
  required VoidCallback onUpdate,
  String? hint,
}) async {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton.icon(
            label: const Text('CANCEL'),
            onPressed: () {
              controller.text = '';
              Navigator.pop(context);
            },
          ),
          TextButton.icon(
            label: const Text('OK'),
            onPressed: () async {
              if (isValid(controller.text)) {
                onUpdate();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                  ),
                );
              }
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}
