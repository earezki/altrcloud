import 'package:flutter/material.dart';

class CloudStorageDashboard extends StatefulWidget {
  const CloudStorageDashboard({super.key});

  @override
  State<CloudStorageDashboard> createState() => _CloudStorageDashboardState();
}

class _CloudStorageDashboardState extends State<CloudStorageDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Cloud Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Code to connect a new cloud storage account
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            CloudStorageCard(provider: 'Google Drive', used: 10, total: 15),
            CloudStorageCard(provider: 'Dropbox', used: 5, total: 20),
            CloudStorageCard(provider: 'OneDrive', used: 2, total: 5),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Code to upload a file
              },
              child: const Text('Upload File'),
            ),
          ],
        ),
      ),
    );
  }
}

class CloudStorageCard extends StatelessWidget {
  final String provider;
  final double used;
  final double total;

  CloudStorageCard(
      {required this.provider, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(provider),
        subtitle: LinearProgressIndicator(
          value: used / total,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        trailing: Text('${used.toInt()} GB / ${total.toInt()} GB'),
      ),
    );
  }
}
