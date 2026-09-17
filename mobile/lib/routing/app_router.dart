import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hums_mobile/features/common/presentation/screens/error_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/home_screen.dart';
import 'package:hums_mobile/features/common/presentation/screens/splash_screen.dart';
import 'package:hums_mobile/routing/route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splashPath,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        name: RouteNames.splash,
        path: RouteNames.splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: RouteNames.home,
        path: RouteNames.homePath,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(
      message: state.error?.message,
    ),
  );
});
