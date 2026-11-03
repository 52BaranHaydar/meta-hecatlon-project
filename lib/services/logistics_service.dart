import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/relief_area_model.dart';
import '../models/shipment_model.dart';
import 'crisis_data_service.dart';

class LogisticsService extends ChangeNotifier {
  LogisticsService({
    CrisisDataService? crisisDataService,
    FirebaseFirestore? firestore,
  }) : _crisisDataService = crisisDataService ?? CrisisDataService(),
       _firestore = firestore ?? _configuredFirestore() {
    _crisisDataService.addListener(_handleAreasChanged);
    _watchShipments();
  }

  final CrisisDataService _crisisDataService;
  final FirebaseFirestore? _firestore;
  final List<ShipmentModel> _shipments = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _shipmentSubscription;
  String? _syncError;

  List<ShipmentModel> get shipments => List.unmodifiable(_shipments);
  String? get syncError => _syncError;

  static FirebaseFirestore? _configuredFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (error) {
      debugPrint('Firestore is unavailable for logistics sync: $error');
      return null;
    }
  }

  void _watchShipments() {
    final firestore = _firestore;
    if (firestore == null) return;

    _shipmentSubscription = firestore
        .collection('shipments')
        .snapshots()
        .listen(
          (snapshot) {
            _shipments
              ..clear()
              ..addAll(
                snapshot.docs.map(
                  (doc) => ShipmentModel.fromMap(doc.data(), docId: doc.id),
                ),
              );
            _shipments.sort((a, b) => b.id.compareTo(a.id));
            _syncError = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _syncError = 'Sevkiyatlar Firestore üzerinden eşitlenemedi: $error';
            debugPrint(_syncError);
            notifyListeners();
          },
        );
  }

  Map<String, Map<String, int>> get centerStocks =>
      Map<String, Map<String, int>>.unmodifiable({
        for (final area in _crisisDataService.areas)
          area.name: Map<String, int>.unmodifiable({
            for (final category in ShipmentModel.categories)
              category: _stockFor(area, category),
          }),
      });

  List<ShipmentModel> shipmentsFor(String carrierId) => _shipments
      .where((shipment) => shipment.carrierId == carrierId)
      .toList(growable: false);

  String stockLabel(String areaName, String category) {
    final area = areaByName(areaName);
    if (area == null) return '0 ${ShipmentModel.unitFor(category)}';
    final entries = area.stock.entries
        .where((entry) => _matchesCategory(entry.key, category))
        .map((entry) => entry.value)
        .toList();
    return entries.isEmpty
        ? '0 ${ShipmentModel.unitFor(category)}'
        : entries.join(', ');
  }

  ReliefAreaModel? areaByName(String name) {
    for (final area in _crisisDataService.areas) {
      if (area.name == name) return area;
    }
    return null;
  }

  Future<void> addShipment(ShipmentModel shipment) async {
    if (shipment.carrierId.trim().isEmpty) {
      throw ArgumentError.value(shipment.carrierId, 'carrierId');
    }
    if (shipment.plateNumber.trim().isEmpty) {
      throw ArgumentError.value(shipment.plateNumber, 'plateNumber');
    }
    if (!ShipmentModel.vehicleTypes.contains(shipment.vehicleType)) {
      throw ArgumentError.value(shipment.vehicleType, 'vehicleType');
    }
    if (!ShipmentModel.categories.contains(shipment.category)) {
      throw ArgumentError.value(shipment.category, 'category');
    }
    if (shipment.quantity <= 0) {
      throw ArgumentError.value(shipment.quantity, 'quantity');
    }
    if (!_crisisDataService.areas.any(
      (area) => area.name == shipment.destination,
    )) {
      throw ArgumentError.value(shipment.destination, 'destination');
    }
    if (_shipments.any((item) => item.id == shipment.id)) {
      throw ArgumentError.value(
        shipment.id,
        'id',
        'Sevkiyat kimliği zaten var.',
      );
    }

    await _firestore
        ?.collection('shipments')
        .doc(shipment.id)
        .set({
          ...shipment.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
    _upsertShipment(shipment);
    notifyListeners();
  }

  Future<void> updateShipmentStatus(
    String shipmentId,
    ShipmentStatus status,
  ) async {
    final index = _shipments.indexWhere(
      (shipment) => shipment.id == shipmentId,
    );
    if (index == -1) {
      throw ArgumentError.value(
        shipmentId,
        'shipmentId',
        'Sevkiyat bulunamadı.',
      );
    }

    var shipment = _shipments[index];
    if (status.index != shipment.status.index + 1) {
      throw StateError('Sevkiyat durumları sırayla güncellenmelidir.');
    }

    ReliefAreaModel? updatedArea;
    if (_firestore != null) {
      updatedArea = await _persistStatusChange(shipmentId, status);
      final remoteShipment = _shipments.firstWhere(
        (item) => item.id == shipmentId,
        orElse: () => shipment,
      );
      shipment = remoteShipment.copyWith(status: status);
    } else if (status == ShipmentStatus.teslimEdildi) {
      updatedArea = _updatedAreaForDelivery(shipment);
      final stockEntry = _matchingStockEntry(updatedArea, shipment.category);
      final stockKey = stockEntry?.key ?? _stockKeyFor(shipment.category);
      await _crisisDataService.updateAreaStock(
        areaId: updatedArea.id,
        itemKey: stockKey,
        quantity: updatedArea.stock[stockKey]!,
      );
    }

    if (_firestore != null && updatedArea != null) {
      _crisisDataService.applyAreaUpdate(updatedArea);
    }
    _upsertShipment(shipment.copyWith(status: status));
    notifyListeners();
  }

  Future<ReliefAreaModel?> _persistStatusChange(
    String shipmentId,
    ShipmentStatus status,
  ) async {
    final firestore = _firestore!;
    final shipmentRef = firestore.collection('shipments').doc(shipmentId);

    return firestore.runTransaction<ReliefAreaModel?>((transaction) async {
      final shipmentSnapshot = await transaction.get(shipmentRef);
      if (!shipmentSnapshot.exists) {
        throw StateError('Firestore sevkiyat kaydı bulunamadı.');
      }
      final shipment = ShipmentModel.fromMap(
        shipmentSnapshot.data()!,
        docId: shipmentSnapshot.id,
      );
      if (status.index != shipment.status.index + 1) {
        throw StateError('Sevkiyat durumu başka bir oturumda değişti.');
      }

      ReliefAreaModel? updatedArea;
      if (status == ShipmentStatus.teslimEdildi) {
        final area = areaByName(shipment.destination);
        if (area == null) {
          throw StateError('Sevkiyat hedef alanı bulunamadı.');
        }
        final areaRef = firestore.collection('areas').doc(area.id);
        final areaSnapshot = await transaction.get(areaRef);
        final currentArea = areaSnapshot.exists
            ? ReliefAreaModel.fromMap(
                areaSnapshot.data()!,
                docId: areaSnapshot.id,
              )
            : area;
        updatedArea = _updatedAreaForDelivery(shipment, currentArea);
        transaction.set(areaRef, updatedArea.toMap(), SetOptions(merge: true));
      }

      transaction.update(shipmentRef, {
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return updatedArea;
    });
  }

  ReliefAreaModel _updatedAreaForDelivery(
    ShipmentModel shipment, [
    ReliefAreaModel? currentArea,
  ]) {
    final area = currentArea ?? areaByName(shipment.destination);
    if (area == null) {
      throw StateError('Sevkiyat hedef alanı bulunamadı.');
    }
    final stockEntry = _matchingStockEntry(area, shipment.category);
    final stockKey = stockEntry?.key ?? _stockKeyFor(shipment.category);
    final currentQuantity = stockEntry == null
        ? 0
        : _quantityFromStock(stockEntry.value);
    final unit = stockEntry == null
        ? ShipmentModel.unitFor(shipment.category)
        : _unitFromStock(stockEntry.value) ??
              ShipmentModel.unitFor(shipment.category);
    return area.copyWith(
      stock: {
        ...area.stock,
        stockKey: '${currentQuantity + shipment.quantity} $unit',
      },
    );
  }

  void _upsertShipment(ShipmentModel shipment) {
    final index = _shipments.indexWhere((item) => item.id == shipment.id);
    if (index < 0) {
      _shipments.insert(0, shipment);
    } else {
      _shipments[index] = shipment;
    }
  }

  String getAIRecommendedDestination(String category) {
    final urgentPoints = getUrgentNeedPoints(category);
    if (urgentPoints.isEmpty) {
      throw ArgumentError.value(
        category,
        'category',
        'Bilinmeyen yük kategorisi.',
      );
    }
    return urgentPoints.first.key;
  }

  List<MapEntry<String, int>> getUrgentNeedPoints(String category) {
    if (!ShipmentModel.categories.contains(category)) {
      throw ArgumentError.value(
        category,
        'category',
        'Bilinmeyen yük kategorisi.',
      );
    }

    final points = _crisisDataService.areas
        .map((area) => MapEntry(area.name, _stockFor(area, category)))
        .toList();
    points.sort((a, b) => a.value.compareTo(b.value));
    return points;
  }

  void _handleAreasChanged() => notifyListeners();

  int _stockFor(ReliefAreaModel area, String category) {
    return area.stock.entries
        .where((entry) => _matchesCategory(entry.key, category))
        .fold(0, (total, entry) => total + _quantityFromStock(entry.value));
  }

  MapEntry<String, String>? _matchingStockEntry(
    ReliefAreaModel area,
    String category,
  ) {
    for (final entry in area.stock.entries) {
      if (_matchesCategory(entry.key, category)) return entry;
    }
    return null;
  }

  bool _matchesCategory(String item, String category) {
    final normalizedItem = _normalize(item);
    final aliases = switch (category) {
      'Su' => const ['su', 'water'],
      'Çadır' => const ['cadir', 'tent'],
      'İlaç' => const [
        'ilac',
        'serum',
        'agri kesici',
        'antibiyotik',
        'ilk yardim',
      ],
      'Mama' => const ['mama', 'formula'],
      'Gıda' => const ['gida', 'food', 'yemek'],
      'Battaniye' => const ['battaniye', 'blanket'],
      _ => const <String>[],
    };
    return aliases.any(normalizedItem.contains);
  }

  int _quantityFromStock(String stock) {
    final match = RegExp(r'\d[\d.,]*').firstMatch(stock);
    if (match == null) {
      final normalized = _normalize(stock);
      if (normalized.contains('bol') || normalized.contains('mevcut')) {
        return 1000000;
      }
      return 0;
    }
    return int.tryParse(match.group(0)!.replaceAll(RegExp(r'[.,]'), '')) ?? 0;
  }

  String? _unitFromStock(String stock) {
    final match = RegExp(r'\d[\d.,]*\s*(.*)').firstMatch(stock);
    final unit = match?.group(1)?.trim();
    return unit == null || unit.isEmpty ? null : unit;
  }

  String _stockKeyFor(String category) {
    return switch (category) {
      'Su' => 'İçme Suyu',
      'Çadır' => 'Çadır',
      'İlaç' => 'Temel İlaçlar',
      'Mama' => 'Bebek Maması',
      'Gıda' => 'Kuru Gıda',
      'Battaniye' => 'Battaniye',
      _ => category,
    };
  }

  String _normalize(String value) => value
      .replaceAll('İ', 'i')
      .replaceAll('ı', 'i')
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');

  @override
  void dispose() {
    _shipmentSubscription?.cancel();
    _crisisDataService.removeListener(_handleAreasChanged);
    super.dispose();
  }
}
