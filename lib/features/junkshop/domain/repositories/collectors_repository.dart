import 'package:ecokuha/features/junkshop/data/models/collector_model.dart';

abstract class ICollectorsRepository {
  Future<List<Collector>> getAvailableCollectors({
    double? latitude,
    double? longitude,
    int limit = 20,
  });

  // Fetch all collectors regardless of status
  Future<List<Collector>> getCollectors({int limit = 100});

  // Fetch only collectors assigned to a specific junkshop (by preferred_junkshop_id)
  // Note: Implementation should include both root-level and nested 'collector_profile.preferred_junkshop_id'
  // and filter to application_status == 'approved'.
  Future<List<Collector>> getCollectorsAssignedToJunkshop({
    required String junkshopId,
    int limit = 100,
  });

  Future<Collector?> getCollectorById(String collectorId);

  Stream<List<Collector>> watchAvailableCollectors({
    double? latitude,
    double? longitude,
    int limit = 20,
  });
}
