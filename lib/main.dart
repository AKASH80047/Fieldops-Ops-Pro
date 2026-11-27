import 'package:flutter/widgets.dart';
import 'app/app.dart';
import 'app/dependency_injection.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/firebase_messaging_service.dart';
import 'features/auth/presentation/auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validateForRelease();
  await FirebaseMessagingService.initialize();
  configureDependencies();
  await restoreAppPalette();
  await authSession.restore(sl<TokenStore>(), sl<ApiClient>());
  await FirebaseMessagingService.bindAuthenticatedSession(
    authSession,
    sl<ApiClient>(),
  );
  runApp(const FieldOpsApp());
}
