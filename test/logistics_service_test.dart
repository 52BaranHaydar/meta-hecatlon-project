import 'package:afet_destek/models/shipment_model.dart';
import 'package:afet_destek/services/logistics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogisticsService', () {
    late LogisticsService service;

    setUp(() {
      service = LogisticsService();
    });

    tearDown(() {
      service.dispose();
    });

    test('recommends the location with the lowest category stock', () {
      expect(
        service.getAIRecommendedDestination('Battaniye'),
        'Kamil Ocak 1 Nolu Çadır Kent',
      );
      expect(service.getUrgentNeedPoints('Battaniye').first.value, 0);
      expect(service.getUrgentNeedPoints('Mama').first.value, 0);
    });

    test('keeps shipments scoped to the carrier who created them', () async {
      await service.addShipment(
        _shipment(id: 'shipment-1', carrierId: 'carrier-1'),
      );
      await service.addShipment(
        _shipment(id: 'shipment-2', carrierId: 'carrier-2'),
      );

      expect(service.shipmentsFor('carrier-1').map((item) => item.id), [
        'shipment-1',
      ]);
      expect(service.shipmentsFor('carrier-2').map((item) => item.id), [
        'shipment-2',
      ]);
    });

    test(
      'accepts statuses in order and updates the relief area stock on delivery',
      () async {
        final shipment = _shipment(id: 'shipment-1');
        await service.addShipment(shipment);
        final stockBefore =
            service.centerStocks[shipment.destination]![shipment.category]!;

        await service.updateShipmentStatus(
          shipment.id,
          ShipmentStatus.yolaCikti,
        );
        await service.updateShipmentStatus(
          shipment.id,
          ShipmentStatus.afetBolgesiGirisinde,
        );
        await service.updateShipmentStatus(
          shipment.id,
          ShipmentStatus.dagitimNoktasinaUlasti,
        );
        await service.updateShipmentStatus(
          shipment.id,
          ShipmentStatus.teslimEdildi,
        );

        expect(service.shipments.single.status, ShipmentStatus.teslimEdildi);
        expect(
          service.centerStocks[shipment.destination]![shipment.category],
          stockBefore + shipment.quantity,
        );
        final area = service.areaByName(shipment.destination)!;
        expect(
          area.stock['İçme Suyu'],
          '${stockBefore + shipment.quantity} Şişe',
        );
        expect(
          ShipmentModel.fromMap(
            shipment.copyWith(status: ShipmentStatus.teslimEdildi).toMap(),
          ).status,
          ShipmentStatus.teslimEdildi,
        );
      },
    );

    test('rejects skipped status transitions', () async {
      final shipment = _shipment(id: 'shipment-1');
      await service.addShipment(shipment);

      await expectLater(
        service.updateShipmentStatus(
          shipment.id,
          ShipmentStatus.afetBolgesiGirisinde,
        ),
        throwsStateError,
      );
    });
  });
}

ShipmentModel _shipment({required String id, String carrierId = 'carrier-1'}) {
  final service = LogisticsService();
  final destination = service.getAIRecommendedDestination('Su');
  service.dispose();
  return ShipmentModel(
    id: id,
    carrierId: carrierId,
    plateNumber: '34 ABC 123',
    vehicleType: 'Tır',
    category: 'Su',
    quantity: 12,
    destination: destination,
  );
}
