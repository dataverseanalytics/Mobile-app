import 'package:flutter/services.dart' show rootBundle;

import 'api/api_client.dart';
import 'mock_data.dart';
import 'models.dart';
import 'serialization.dart';

sealed class ScanFailure implements Exception {
  const ScanFailure(this.message);
  final String message;
}

final class NoFoodDetected extends ScanFailure {
  const NoFoodDetected([
    super.message = "We couldn't spot any food. Try a closer, brighter photo.",
  ]);
}

final class ScanNetworkFailure extends ScanFailure {
  const ScanNetworkFailure()
    : super("You're offline. Connect to the internet to scan a meal.");
}

/// Free scans used up — the app should show the paywall.
final class ScanNeedsPro extends ScanFailure {
  const ScanNeedsPro([
    super.message =
        "You've used your free scans. Upgrade to Pro for unlimited scans.",
  ]);
}

final class ScanServerFailure extends ScanFailure {
  const ScanServerFailure(super.message);
}

/// Result of a scan. [scansLeft] comes from the server (null = unlimited);
/// [fromServer] is false in on-device demo mode.
typedef ScanOutcome = ({Meal meal, int? scansLeft, bool fromServer});

/// AI meal recognition, barcode lookup and food search.
///
/// With a backend ([api] set) photos are analysed server-side — the AI key
/// never ships in the app. Without one, curated demo results are used so
/// every screen still works offline.
class ScanRepository {
  ScanRepository({this.api});

  final ApiClient? api;
  int _cursor = 0;

  /// The photo the camera will "see" next (demo viewfinder until the
  /// camera plugin is connected).
  String nextPhoto() {
    final samples = MockData.scanSamples(DateTime.now());
    return samples[_cursor % samples.length].photo ?? '';
  }

  Future<ScanOutcome> analyzePhoto(String photo) async {
    final client = api;
    _cursor++;
    if (client == null) return _analyzeLocally(photo);

    final List<int> bytes;
    try {
      bytes = (await rootBundle.load(photo)).buffer.asUint8List();
    } on Object {
      throw const NoFoodDetected();
    }
    try {
      final json = (await client.uploadImage(
        '/v1/scan',
        field: 'photo',
        bytes: bytes,
        filename: photo.split('/').last,
        contentType: photo.endsWith('.png') ? 'image/png' : 'image/jpeg',
      )).asMap;
      final meal = Json.toMeal(json['meal']);
      final left = json['scansLeft'];
      return (
        // The server doesn't keep the photo; show the one the user took.
        meal: Meal(
          id: meal.id,
          name: meal.name,
          photo: photo,
          loggedAt: meal.loggedAt.toLocal(),
          type: meal.type,
          items: meal.items,
          healthScore: meal.healthScore,
        ),
        scansLeft: left is int ? left : null,
        fromServer: true,
      );
    } on ApiException catch (e) {
      throw switch (e.status) {
        0 => const ScanNetworkFailure(),
        402 => ScanNeedsPro(e.message),
        422 => NoFoodDetected(e.message),
        _ => ScanServerFailure(e.message),
      };
    }
  }

  Future<ScanOutcome> _analyzeLocally(String photo) async {
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    final samples = MockData.scanSamples(DateTime.now());
    final match = samples.where((m) => m.photo == photo).firstOrNull;
    if (match == null) throw const NoFoodDetected();
    return (
      meal: match.copyWith(id: 'meal-${DateTime.now().microsecondsSinceEpoch}'),
      scansLeft: null,
      fromServer: false,
    );
  }

  /// Demo barcode (seeded in the backend's food database).
  static const demoBarcode = '8901234567890';

  Future<FoodEntry> lookupBarcode(String code) async {
    final client = api;
    if (client == null) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return MockData.barcodeProduct;
    }
    try {
      return _food((await client.get('/v1/foods/barcode/$code')).asMap);
    } on ApiException catch (e) {
      throw e.status == 0
          ? const ScanNetworkFailure()
          : ScanServerFailure(e.message);
    }
  }

  /// Search the food database (server when connected, bundled list offline).
  Future<List<FoodEntry>> search(String query) async {
    final q = query.trim();
    final client = api;
    if (client != null) {
      try {
        final list = (await client.get(
          '/v1/foods',
          query: {'q': q, 'limit': '25'},
        )).asList;
        return [for (final f in list) _food(f.asMap)];
      } on ApiException catch (e) {
        if (!e.isNetwork) rethrow;
        // Offline: fall back to the bundled list below.
      }
    }
    final lower = q.toLowerCase();
    if (lower.isEmpty) return MockData.foodDatabase.take(8).toList();
    return MockData.foodDatabase
        .where((f) => f.name.toLowerCase().contains(lower))
        .toList();
  }

  FoodEntry _food(Map<String, Object?> j) => FoodEntry(
    name: j['name'] as String? ?? 'Food',
    unit: j['unit'] as String? ?? '1 serving',
    macros: Json.toMacros(j['macros']),
    photo: j['photo'] as String?,
    brand: j['brand'] as String?,
    aiEstimated: j['aiEstimated'] == true,
  );
}
