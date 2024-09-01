### resources
Deep link : https://medium.com/flutter-community/deep-links-and-flutter-applications-how-to-handle-them-properly-8c9865af9283
Deep link redirect issue solution: https://github.com/openid/AppAuth-Android/issues/977
For Github try device flow to avoid having the secret https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow

### Github connecting steps:
1. create an oauth application and assign your own clientid / secret because of the api rate limit.
2. create a github account
3. create an organization with name starting with **altrcloud**
4. give permission to the organization via: https://github.com/settings/connections/applications/:clientId
5. connect user via the application.

TODO: 
1. check & renew token after expiration

### scripts
generate **freezed** objects: ```flutter pub run build_runner build```

### Suggested names:
- AltCloud/AltSky (Alternative cloud)
- CloudFusion
- MultiCloudHub
- CloudBalancer / FreeCloudBalancer
- CloudMate
- Storify
- CloudMosaic
- CloudUnity
- SkyManager
- CloudFlow

### High-Level Plan

**Requirements**:
    - Cloud storage providers (Git, Google Drive, Dropbox, OneDrive, Amazon S3, Box, ...).
    - OAuth 2.0 authentication for each provider.
    - Client-side data balancing algorithm to distribute files across connected accounts.
    - Data management features (upload, download, search, delete, sync, etc.).
    - UI screens for login, cloud account management, file upload,
            and file management.

**Security Considerations**:
    - Securely store authentication tokens and user credentials.
    - Implement error handling and data validation to ensure the app's robustness.

**Features**:
    - User authentication and connection of multiple cloud storage accounts.
    - Display current storage usage and quotas.
    - Upload files and automatically distribute them across connected accounts.
    - Download and synchronize files from multiple accounts.
    - File management (delete, move, rename).
    - Notification and error handling.
    - Unified Dashboard: 
        Combined Storage Overview: Display total, used, and available storage across all connected accounts.
        Account Management: Add, remove, and manage connected cloud storage accounts from different providers.
    - File Management: Upload and Download: Ability to upload and download files to and from any connected cloud storage account.
    - Automatic File Distribution: Distribute files across multiple cloud accounts based on available storage space.
    - File Syncing: Synchronize files between local storage and cloud accounts, as well as between different cloud accounts.
    - Batch Operations: Perform batch uploads, downloads, deletions, and other operations
    - Rename and Delete Files: Rename or delete files directly from the application.
    - Folder Management: Create, rename, and delete folders across different cloud storage providers.
    - Unified Search: Search for files across all connected cloud storage accounts.
    - Advanced Filtering: Filter files by size, type, date modified, and other criteria.
    - Storage Alerts: Notifications when storage quotas are nearing limits.
    - Usage Analytics: Detailed analytics on storage usage per account and overall.
    - End-to-End Encryption: Option for users to encrypt files before uploading them to cloud storage.
    - Parallel Uploads/Downloads: Optimize file transfer speeds by supporting parallel uploads and downloads.
    - Caching Mechanism: Implement caching for faster access to frequently used files.

To provide a comprehensive and user-friendly multi-cloud management application, the following screens should be supported:

1. **Login Screen**:
    - **Purpose**: Allow users to log in or sign up.
    - **Features**:
        - Email and password fields.
        - OAuth login options for popular providers (Google, Apple, Facebook).
        - Password reset option.

2. **Home/Dashboard Screen**:
    - **Purpose**: Central hub for accessing various features.
    - **Features**:
        - Overview of connected cloud accounts with storage usage.
        - Quick access to recent files and folders.
        - Notifications and alerts.

3. **Cloud Account Management Screen**:
    - **Purpose**: Manage connected cloud storage accounts.
    - **Features**:
        - List of connected accounts.
        - Options to add, remove, or edit cloud accounts.
        - Display of storage quotas and usage for each account.

4. **File Explorer Screen**:
    - **Purpose**: Navigate through files and folders.
    - **Features**:
        - List and grid views for files and folders.
        - File sorting and filtering options.
        - Folder navigation and breadcrumb trail.

5. **File Upload/Download Screen**:
    - **Purpose**: Handle file transfers to and from cloud accounts.
    - **Features**:
        - File selection from local storage.
        - Progress indicator for uploads and downloads.
        - Options for batch operations.

6. **File Management Screen**:
    - **Purpose**: Perform operations on files and folders.
    - **Features**:
        - Move, copy, delete, rename files and folders.
        - Share files and generate sharing links.
        - View file details and properties.

7. **Settings Screen**:
    - **Purpose**: Customize app settings.
    - **Features**:
        - Account settings (profile, password).
        - Application settings (theme, notifications).
        - Cloud storage settings (manage connected accounts).

8. **Notifications and Alerts Screen**:
    - **Purpose**: Display important notifications and alerts.
    - **Features**:
        - List of recent notifications.
        - Options to manage and clear notifications.
        - Storage quota alerts.

9. **Search Screen**:
    - **Purpose**: Search for files across all connected cloud accounts.
    - **Features**:
        - Unified search bar.
        - Advanced search filters (file type, size, date).
        - Search results display with file previews.

10. **Sync Management Screen**:
    - **Purpose**: Manage synchronization between local and cloud storage.
    - **Features**:
        - Sync settings and preferences.
        - Sync status and progress indicators.
        - Conflict resolution options.

11. **Help and Support Screen**:
    - **Purpose**: Provide assistance and support to users.
    - **Features**:
        - FAQs and troubleshooting guides.
        - Contact support options.
        - Links to tutorials and documentation.

12. **Backup and Restore Screen**:
    - **Purpose**: Manage backups and restore files.
    - **Features**:
        - Schedule automatic backups.
        - View backup history.
        - Restore files from backups.

### Example Navigation Flow

**Home/Dashboard Screen**:
    - Provides an overview and quick links to other features.
    - From here, users can navigate to Cloud Account Management, File Explorer, or Settings.

**Cloud Account Management Screen**:
    - User can add or remove cloud accounts.
    - Detailed view of each account’s storage usage.

**File Explorer Screen**:
    - Allows users to browse and manage files.
    - Users can select files for upload, download, or perform other operations.

**File Upload/Download Screen**:
    - Users initiate file uploads or downloads.
    - Progress and status are shown.

**File Management Screen**:
    - Users can move, copy, delete, or rename files.
    - Share files and view details.

**Settings Screen**:
    - Access app settings and customization options.
    - Manage user profile and connected cloud storage settings.

**Notifications and Alerts Screen**:
    - View and manage notifications related to storage and file operations.

**Search Screen**:
    - Search for files across all cloud accounts.
    - Filter and view search results.

**Sync Management Screen**:
   - Set up and manage file synchronization.
   - Monitor sync status.

**Help and Support Screen**:
    - Access help resources and contact support.

**Backup and Restore Screen**:
    - Schedule backups and restore files as needed.

### Flutter UI Example
```dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Storage Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  GoogleSignInAccount? _currentUser;
  String _storageStatus = 'No accounts connected';

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
      });
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _connectGoogleDrive() async {
    try {
      await _googleSignIn.signIn();
      setState(() {
        _storageStatus = 'Google Drive connected';
      });
    } catch (error) {
      print(error);
    }
  }

  Future<void> _uploadFile() async {
    if (_currentUser != null) {
      // Implement file upload logic using Google Drive API
      var headers = await _currentUser!.authHeaders;
      var uploadRequest = http.Request(
          'POST', Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'));
      uploadRequest.headers.addAll(headers);
      uploadRequest.body = 'Your file content here';
      var response = await uploadRequest.send();
      if (response.statusCode == 200) {
        print('File uploaded successfully!');
      } else {
        print('Failed to upload file');
      }
    } else {
      print('No account connected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cloud Storage Manager'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _connectGoogleDrive,
              child: Text('Connect Google Drive'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadFile,
              child: Text('Upload File'),
            ),
            SizedBox(height: 20),
            Text(_storageStatus),
          ],
        ),
      ),
    );
  }
}
```

## Show storage space usage per cloud provider
```dart

class CloudStorageDashboard extends StatefulWidget {
  @override
  _CloudStorageDashboardState createState() => _CloudStorageDashboardState();
}

class _CloudStorageDashboardState extends State<CloudStorageDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi-Cloud Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Code to upload a file
              },
              child: Text('Upload File'),
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

  CloudStorageCard({required this.provider, required this.used, required this.total});

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
```

### Data Balancing Algorithm Example
```dart
import 'dart:math';

class CloudStorageAccount {
  final String provider;
  final int totalQuota;
  int usedQuota;

  CloudStorageAccount(this.provider, this.totalQuota, this.usedQuota);
}

void balanceData(List<CloudStorageAccount> accounts, int fileSize) {
  accounts.sort((a, b) => (a.totalQuota - a.usedQuota).compareTo(b.totalQuota - b.usedQuota));
  for (var account in accounts) {
    if (account.totalQuota - account.usedQuota >= fileSize) {
      account.usedQuota += fileSize;
      print('File of size $fileSize uploaded to ${account.provider}');
      return;
    }
  }
  print('Not enough space in any account to upload the file');
}

void main() {
  var accounts = [
    CloudStorageAccount('Google Drive', 15000, 5000),
    CloudStorageAccount('Dropbox', 20000, 12000),
    CloudStorageAccount('OneDrive', 5000, 1000),
  ];

  balanceData(accounts, 3000); // Adjust file size as needed
}
```
