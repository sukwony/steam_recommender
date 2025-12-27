import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/backend_api_service.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final databaseService = DatabaseService();
  await databaseService.initialize();

  final backendApiService = BackendApiService();

  runApp(MyApp(
    databaseService: databaseService,
    backendApiService: backendApiService,
  ));
}

class MyApp extends StatelessWidget {
  final DatabaseService databaseService;
  final BackendApiService backendApiService;

  const MyApp({
    super.key,
    required this.databaseService,
    required this.backendApiService,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(databaseService, backendApiService)..initialize(),
      child: MaterialApp(
        title: 'WNTP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
