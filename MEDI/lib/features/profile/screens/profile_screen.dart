import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  @override
  Widget build(BuildContext context) {
    // Determine user info
    final String userEmail = user?.email ?? 'No Email';
    final String? userName = user?.userMetadata?['full_name'];
    final String displayName = userName ?? (userEmail.split('@').first);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              userEmail,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(
                Icons.security_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Privacy & Security'),
              subtitle: const Text('Biometrics, auto-lock timeout'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/security-settings'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.bug_report_outlined,
                color: Colors.orange,
              ),
              title: const Text('Supabase Diagnostics'),
              subtitle: const Text('Test database connection'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/diagnostic'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.terminal_outlined,
                color: Colors.purple,
              ),
              title: const Text('App Diagnostics Log'),
              subtitle: const Text('View runtime errors & logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/diagnostics'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const Spacer(),
            CustomButton(
              text: 'Sign Out',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
              backgroundColor: Colors.red.shade50,
              textColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
