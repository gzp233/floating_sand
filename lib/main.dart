import 'package:flutter/material.dart';

import 'app.dart';
import 'services/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/// 应用启动壳层，避免初始化异常直接导致 Web 空白页。
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    _initializeFuture = AppDatabase.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFF3F1EB),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '应用初始化失败',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16302B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '当前页面没有继续渲染，是因为本地数据库在启动阶段抛出了异常。',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(
                            color: Color(0xFF7A3B30),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _initializeFuture = AppDatabase.instance.initialize();
                            });
                          },
                          child: const Text('重试初始化'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return const PersonalRecordApp();
      },
    );
  }
}

