import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MandatoryUpdateScreen extends StatelessWidget {
  const MandatoryUpdateScreen({
    super.key,
    required this.message,
    required this.updateUrl,
    this.latestVersion,
  });

  final String message;
  final String updateUrl;
  final String? latestVersion;

  Future<void> _launchUpdateUrl(BuildContext context) async {
    final uri = Uri.tryParse(updateUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط التحديث')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.system_update_alt,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'يجب تحديث التطبيق',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (latestVersion != null && latestVersion!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'الإصدار المتوفر: $latestVersion',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _launchUpdateUrl(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('تحديث الآن'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
