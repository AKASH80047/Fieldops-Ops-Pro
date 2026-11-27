import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/auth/data/auth_repository.dart';
import '../core/network/api_client.dart';
import '../features/integrations/data/integration_repository.dart';
import '../features/technician/data/technician_repository.dart';
import '../features/admin/data/admin_repository.dart';

final sl = GetIt.instance;
void configureDependencies() {
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<TokenStore>(() => TokenStore(sl()));
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl(), sl()));
  sl.registerLazySingleton<IntegrationRepository>(
    () => IntegrationRepository(sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => ApiConfig.useMocks
        ? MockAuthRepository()
        : ApiAuthRepository(sl(), sl()),
  );
  sl.registerLazySingleton<TechnicianRepository>(
    () => ApiConfig.useMocks
        ? MockTechnicianRepository()
        : ApiTechnicianRepository(sl()),
  );
  sl.registerLazySingleton<AdminRepository>(
    () => ApiConfig.useMocks ? MockAdminRepository() : ApiAdminRepository(sl()),
  );
}
