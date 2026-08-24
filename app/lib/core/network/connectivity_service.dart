import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  Stream<ConnectivityStatus> get statusStream => _connectivity.onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none) 
            ? ConnectivityStatus.online 
            : ConnectivityStatus.offline,
      );
      
  Future<ConnectivityStatus> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none) 
        ? ConnectivityStatus.online 
        : ConnectivityStatus.offline;
  }
}
