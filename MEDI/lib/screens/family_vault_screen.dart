import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vault_screen.dart';
import '../services/vault_password_service.dart';

class FamilyVaultScreen extends StatefulWidget {
  const FamilyVaultScreen({Key? key}) : super(key: key);

  @override
  State<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends State<FamilyVaultScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> vaults = [];
  Map<String, int> vaultDocCounts = {}; // vaultId -> doc count
  bool isLoading = false;
  bool isCreating = false;

  String memberName = "";
  String memberRelation = "";

  @override
  void initState() {
    super.initState();
    fetchVaults();
  }

  Future<void> fetchVaults() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        // Handle unauthenticated state gracefully
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
            ),
          );
          // Optional: Navigate to login
        }
        return;
      }

      final userId = user.id;

      final data = await supabase
          .from('family_vaults')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      // Ensure specific type casting
      final List<Map<String, dynamic>> typedData =
          List<Map<String, dynamic>>.from(data);

      // Fetch document counts for each vault
      final Map<String, int> counts = {};
      for (final vault in typedData) {
        final vaultId = vault['id']?.toString();
        if (vaultId != null) {
          try {
            final docs = await supabase
                .from('prescriptions')
                .select('id')
                .eq('vault_id', vaultId)
                .eq('user_id', userId);
            counts[vaultId] = (docs as List).length;
          } catch (_) {
            counts[vaultId] = 0;
          }
        }
      }

      if (mounted) {
        setState(() {
          vaults = typedData;
          vaultDocCounts = counts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching vaults: $e');
      if (mounted) {
        setState(() => isLoading = false);
        if (e.toString().contains('column') &&
            e.toString().contains('description')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Schema Warning: Description column missing. Please run migration.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading family members: $e')),
          );
        }
      }
    }
  }

  Future<void> createVault() async {
    if (memberName.trim().isEmpty || memberRelation.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and relation')),
      );
      return;
    }

    setState(() => isCreating = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final userId = user.id;

      await supabase.from('family_vaults').insert({
        'owner_id': userId,
        'vault_name': memberName.trim(),
        'description': memberRelation.trim(),
      }).select();

      if (mounted) {
        setState(() {
          memberName = "";
          memberRelation = "";
          isCreating = false;
        });
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Family member added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        fetchVaults();
      }
    } catch (e) {
      print('❌ Error creating vault: $e');
      if (mounted) {
        setState(() => isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteVault(Map<String, dynamic> vault) async {
    final vaultId = vault['id'];
    final vaultName = vault['vault_name'] ?? 'Unknown';
    if (vaultId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vault'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete "$vaultName"\'s vault?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'All documents inside this vault will also be permanently deleted. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => isLoading = true);

      // Delete all prescriptions linked to this vault first
      await supabase.from('prescriptions').delete().eq('vault_id', vaultId);

      // Delete the vault itself
      await supabase.from('family_vaults').delete().eq('id', vaultId);

      // Clear the stored vault password
      await VaultPasswordService.clearPassword(vaultId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$vaultName" vault deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchVaults();
      }
    } catch (e) {
      print('❌ Error deleting vault: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting vault: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showAddMemberDialog() {
    String localName = "";
    String localRelation = "";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Family Member"),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (val) => localName = val,
                  decoration: const InputDecoration(
                    labelText: "Member Name",
                    hintText: "e.g. John Doe",
                    prefixIcon: Icon(Icons.person),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) => localRelation = val,
                  decoration: const InputDecoration(
                    labelText: "Relation",
                    hintText: "e.g. Father, Spouse",
                    prefixIcon: Icon(Icons.people),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () {
                      if (localName.isNotEmpty && localRelation.isNotEmpty) {
                        setState(() {
                          memberName = localName;
                          memberRelation = localRelation;
                        });
                        createVault();
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Add Member"),
            ),
          ],
        ),
      ),
    );
  }

  void openVault(Map<String, dynamic> vault) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VaultScreen(vaultId: vault['id'], vaultName: vault['vault_name']),
      ),
    ).then((_) {
      // Refresh doc counts when returning from the vault screen
      fetchVaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Family Vaults"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchVaults),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : vaults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No family members added',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a family member to manage their documents',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vaults.length,
              itemBuilder: (context, index) {
                final vault = vaults[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        (vault['vault_name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      vault['vault_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vault['description'] ?? 'Family Member',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vaultDocCounts[vault['id']?.toString()] ?? 0} document(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: () => openVault(vault),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              "Open",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: () => _deleteVault(vault),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: 'Delete Vault',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    onTap: () => openVault(vault),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'family_vault_fab',
        onPressed: showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }
}
