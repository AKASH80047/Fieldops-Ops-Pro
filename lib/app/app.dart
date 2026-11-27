import 'package:flutter/material.dart';
import 'routes.dart';
import '../core/theme/app_theme.dart';

class FieldOpsApp extends StatelessWidget {
  const FieldOpsApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: appPalette,
    builder: (context, palette, _) => MaterialApp.router(
      title: 'FieldOps Pro',
      debugShowCheckedModeBanner: false,
      theme: appTheme(palette),
      routerConfig: appRouter,
    ),
  );
}
