import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isWifiEnabled() async {
  final List<ConnectivityResult> connectivityResult =
      await (Connectivity().checkConnectivity());

  return connectivityResult.contains(ConnectivityResult.wifi);
}
