import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../auth/auth_token_store.dart';
import 'api_client_provider.dart';
import 'test_network_config.dart';

Future<void> showTestNetworkConfigDialog(
  BuildContext context,
  WidgetRef ref, {
  bool sessionBootstrapFollows = false,
}) async {
  if (!TestNetworkTools.enabled) {
    return;
  }

  final service = ref.read(testNetworkConfigProvider);
  final hostController = TextEditingController(text: service.proxyHost);
  final portController = TextEditingController(
    text: service.proxyPort?.toString() ?? '',
  );
  var useProduction = service.useProductionEnvironment;
  String? errorText;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            final host = hostController.text.trim();
            final portText = portController.text.trim();
            final port = int.tryParse(portText);
            if (host.isNotEmpty &&
                (port == null || port <= 0 || port > 65535)) {
              setState(() => errorText = '请输入 1–65535 的有效端口');
              return;
            }
            final environmentChanged =
                service.useProductionEnvironment != useProduction;
            await service.save(
              host: host,
              port: host.isEmpty ? null : port,
              useProduction: useProduction,
            );
            if (environmentChanged) {
              await ref.read(authTokenStoreProvider.notifier).clear();
              await ref.read(userInfoStoreProvider.notifier).clear();
            }
            ref.invalidate(apiClientProvider);
            if (environmentChanged && !sessionBootstrapFollows) {
              await ref.read(authControllerProvider.notifier).load();
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          }

          return AlertDialog(
            title: const Text('测试网络配置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hostController,
                    decoration: const InputDecoration(
                      labelText: '代理地址（可不填）',
                      hintText: '例如 192.168.1.10',
                    ),
                  ),
                  TextField(
                    controller: portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '代理端口',
                      hintText: '例如 8888',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('测试环境')),
                      ButtonSegment(value: true, label: Text('正式环境')),
                    ],
                    selected: {useProduction},
                    onSelectionChanged: (selection) {
                      setState(() => useProduction = selection.single);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    useProduction ? '当前将请求正式域名' : '当前将请求测试域名',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  hostController.clear();
                  portController.clear();
                  setState(() => errorText = null);
                },
                child: const Text('清空代理'),
              ),
              FilledButton(onPressed: save, child: const Text('保存并继续')),
            ],
          );
        },
      );
    },
  );

  hostController.dispose();
  portController.dispose();
}
