import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/diagnostics_service.dart';
import '../shared/theme/app_colors.dart';

/// Full-screen log viewer. Navigate to '/diagnostics'.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final List<DiagEntry> _entries = [];
  DiagLevel? _filterLevel;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _entries.addAll(DiagnosticsService.entries);

    // Listen for new entries in real time
    DiagnosticsService.stream.listen((e) {
      if (!mounted) return;
      setState(() => _entries.insert(0, e));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<DiagEntry> get _filtered => _filterLevel == null
      ? _entries
      : _entries.where((e) => e.level == _filterLevel).toList();

  Color _levelColor(DiagLevel level) => switch (level) {
    DiagLevel.info => Colors.blueGrey,
    DiagLevel.warning => Colors.orange,
    DiagLevel.error => Colors.red,
    DiagLevel.fatal => Colors.purple,
  };

  IconData _levelIcon(DiagLevel level) => switch (level) {
    DiagLevel.info => Icons.info_outline,
    DiagLevel.warning => Icons.warning_amber_outlined,
    DiagLevel.error => Icons.error_outline,
    DiagLevel.fatal => Icons.dangerous_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.bug_report_outlined, size: 20),
            SizedBox(width: 8),
            Text('Diagnostics Log', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          // Filter chip
          PopupMenuButton<DiagLevel?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by level',
            onSelected: (v) => setState(() => _filterLevel = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: DiagLevel.info, child: Text('Info')),
              const PopupMenuItem(
                value: DiagLevel.warning,
                child: Text('Warning'),
              ),
              const PopupMenuItem(value: DiagLevel.error, child: Text('Error')),
              const PopupMenuItem(value: DiagLevel.fatal, child: Text('Fatal')),
            ],
          ),
          // Copy all
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all logs',
            onPressed: () {
              final text = filtered.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          // Export to file
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export log file',
            onPressed: () async {
              final path = await DiagnosticsService.exportToFile();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Saved: $path')));
              }
            },
          ),
          // Clear
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear logs',
            onPressed: () {
              DiagnosticsService.clear();
              setState(() => _entries.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          _buildStatsBar(),
          const Divider(height: 1, color: Color(0xFF30363D)),
          // Log list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No log entries yet.\nErrors will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildEntry(filtered[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Scroll to bottom',
        backgroundColor: AppColors.primary,
        onPressed: () => _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
        child: const Icon(Icons.arrow_downward, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsBar() {
    final counts = {
      DiagLevel.info: _entries.where((e) => e.level == DiagLevel.info).length,
      DiagLevel.warning: _entries
          .where((e) => e.level == DiagLevel.warning)
          .length,
      DiagLevel.error: _entries.where((e) => e.level == DiagLevel.error).length,
      DiagLevel.fatal: _entries.where((e) => e.level == DiagLevel.fatal).length,
    };
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: DiagLevel.values.map((level) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => setState(
                () => _filterLevel = _filterLevel == level ? null : level,
              ),
              child: Row(
                children: [
                  Icon(_levelIcon(level), size: 14, color: _levelColor(level)),
                  const SizedBox(width: 4),
                  Text(
                    '${counts[level]}',
                    style: TextStyle(
                      color: _filterLevel == level
                          ? _levelColor(level)
                          : Colors.white54,
                      fontSize: 13,
                      fontWeight: _filterLevel == level
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEntry(DiagEntry entry) {
    final color = _levelColor(entry.level);
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}.'
        '${(entry.timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}';

    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: entry.toString()));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entry copied')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_levelIcon(entry.level), size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  entry.level.name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '[${entry.tag}]',
                  style: const TextStyle(color: Colors.cyan, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  time,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            if (entry.stackTrace != null) ...[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Stack trace ▸',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                children: [
                  Text(
                    entry.stackTrace!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
