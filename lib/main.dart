import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'core/api.dart';
import 'core/router.dart';
import 'core/session.dart';
import 'core/theme.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(ApiClient());
  await session.restore();
  runApp(AgroBidAdmin(session: session));
}

class AgroBidAdmin extends StatefulWidget {
  const AgroBidAdmin({super.key, required this.session});

  final Session session;

  @override
  State<AgroBidAdmin> createState() => _AgroBidAdminState();
}

class _AgroBidAdminState extends State<AgroBidAdmin> {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AgroBid Admin',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: buildTheme(),
    );
  }
}
