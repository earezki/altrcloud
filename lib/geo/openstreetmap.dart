import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenStreetMapGeocoding {
  /// Forward Geocoding: Convert address to latitude and longitude
  static Future<Map<String, dynamic>?> forwardGeocoding(String address) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1');

    final response = await http.get(url, headers: {
      'User-Agent': 'FlutterGeocodingApp/1.0 (your_email@example.com)',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return {
          'latitude': double.parse(data[0]['lat']),
          'longitude': double.parse(data[0]['lon']),
          'display_name': data[0]['display_name'],
        };
      }
    }
    return null;
  }

  /// Reverse Geocoding: Convert latitude and longitude to an address
  static Future<String?> reverseGeocoding(
      double latitude, double longitude) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json');

    final response = await http.get(url, headers: {
      'User-Agent': 'FlutterGeocodingApp/1.0 (your_email@example.com)',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'];
    }
    return null;
  }
}
