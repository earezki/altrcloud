import 'package:flutter/material.dart';

class InfoBar extends StatelessWidget {
  final String info;

  const InfoBar({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.all(16.0),
      child: Text(
        info,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
