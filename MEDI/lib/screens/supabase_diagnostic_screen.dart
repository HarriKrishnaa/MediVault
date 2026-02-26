import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Diagnostic screen to test Supabase connectivity and schema
class SupabaseDiagnosticScreen extends StatefulWidget {
  const SupabaseDiagnosticScreen({super.key});

  @override
  State<SupabaseDiagnosticScreen> createState() =>
      _SupabaseDiagnosticScreenState();
}

class _SupabaseDiagnosticScreenState extends State<SupabaseDiagnosticScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  void _log(String message) {
    setState(() {
      _logs.add(
        '${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)} - $message',
      );
    });
    print(message);
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _logs.clear();
      _isRunning = true;
    });

    _log('🔍 Starting Supabase diagnostics...');

    try {
      // Test 1: Check authentication
      _log('Test 1: Checking authentication...');
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _log('✅ User authenticated: ${user.email}');
        _log('   User ID: ${user.id}');
      } else {
        _log('❌ No user authenticated');
        setState(() => _isRunning = false);
        return;
      }

      // Test 2: Check if prescriptions table exists
      _log('\nTest 2: Checking prescriptions table...');
      try {
        final response = await Supabase.instance.client
            .from('prescriptions')
            .select('id')
            .limit(1);
        _log('✅ Prescriptions table exists');
        _log('   Sample query returned: ${response.length} rows');
      } catch (e) {
        _log('❌ Error accessing prescriptions table');
        _log('   Error: $e');
        if (e.toString().contains('relation') &&
            e.toString().contains('does not exist')) {
          _log('   💡 Solution: Run the SQL from SUPABASE_SETUP.md');
        }
      }

      // Test 3: Try inserting a test record
      _log('\nTest 3: Testing insert permission...');
      try {
        final testData = {
          'user_id': user.id,
          'image_cid': 'TEST_CID_${DateTime.now().millisecondsSinceEpoch}',
          'image_url': 'https://ipfs.io/ipfs/test',
          'file_name': 'diagnostic_test.jpg',
          'mime_type': 'image/jpeg',
          'is_encrypted': true,
        };

        _log('   Attempting insert with data: $testData');

        final insertResponse = await Supabase.instance.client
            .from('prescriptions')
            .insert(testData)
            .select();

        _log('✅ Insert successful!');
        _log('   Inserted ID: ${insertResponse[0]['id']}');

        // Clean up test record
        final testId = insertResponse[0]['id'];
        await Supabase.instance.client
            .from('prescriptions')
            .delete()
            .eq('id', testId);
        _log('   Test record cleaned up');
      } catch (e) {
        _log('❌ Insert failed');
        _log('   Error: $e');
        if (e.toString().contains('row-level security')) {
          _log('   💡 Solution: Check RLS policies in Supabase');
        }
      }

      // Test 4: Check family_vaults table
      _log('\nTest 4: Checking family_vaults table...');
      try {
        await Supabase.instance.client
            .from('family_vaults')
            .select('id, vault_name, owner_id')
            .limit(1);
        _log('✅ Family vaults table exists');
        _log('   Schema validated: owner_id and vault_name columns found');
      } catch (e) {
        _log('❌ Error accessing family_vaults table');
        _log('   Error: $e');
        if (e.toString().contains('column') &&
            e.toString().contains('does not exist')) {
          _log(
            '   💡 Solution: Run the migration script from SUPABASE_SETUP.md',
          );
          _log('   The table might use old column names (created_by, name)');
        }
      }

      // Test 5: Check vault_members table
      _log('\nTest 5: Checking vault_members table...');
      try {
        await Supabase.instance.client
            .from('vault_members')
            .select('id, member_email')
            .limit(1);
        _log('✅ Vault members table exists');
        _log('   Schema validated: member_email column found');
      } catch (e) {
        _log('❌ Error accessing vault_members table');
        _log('   Error: $e');
        if (e.toString().contains('column') &&
            e.toString().contains('does not exist')) {
          _log('   💡 Solution: Add member_email column via migration script');
        }
      }

      // Test 6: Test family vault creation
      _log('\nTest 6: Testing family vault creation...');
      try {
        final testVaultData = {
          'owner_id': user.id,
          'vault_name': 'Test Vault ${DateTime.now().millisecondsSinceEpoch}',
        };

        _log('   Attempting to create test vault...');

        final vaultResponse = await Supabase.instance.client
            .from('family_vaults')
            .insert(testVaultData)
            .select();

        _log('✅ Vault creation successful!');
        _log('   Created vault ID: ${vaultResponse[0]['id']}');

        // Clean up test vault
        final testVaultId = vaultResponse[0]['id'];
        await Supabase.instance.client
            .from('family_vaults')
            .delete()
            .eq('id', testVaultId);
        _log('   Test vault cleaned up');
      } catch (e) {
        _log('❌ Vault creation failed');
        _log('   Error: $e');
        if (e.toString().contains('column') &&
            e.toString().contains('does not exist')) {
          _log('   💡 Solution: Column name mismatch - run migration script');
        } else if (e.toString().contains('row-level security')) {
          _log('   💡 Solution: Check RLS policies for family_vaults');
        }
      }

      _log('\n✅ Diagnostics complete!');
    } catch (e) {
      _log('❌ Unexpected error: $e');
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Diagnostics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runDiagnostics,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running...' : 'Run Diagnostics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Click "Run Diagnostics" to start',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        Color textColor = Colors.white;
                        if (log.contains('✅')) {
                          textColor = Colors.green;
                        } else if (log.contains('❌')) {
                          textColor = Colors.red;
                        } else if (log.contains('💡')) {
                          textColor = Colors.yellow;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            log,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
