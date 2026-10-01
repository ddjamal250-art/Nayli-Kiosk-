import 'package:flutter/material.dart';
import '../data/import_result.dart';
import '../../../../core/theme/app_theme.dart';

class LiveAnalysisConsole extends StatefulWidget {
  final Stream<AnalysisEvent> stream;
  final Function(AnalysisSummary) onComplete;

  const LiveAnalysisConsole({
    Key? key,
    required this.stream,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LiveAnalysisConsole> createState() => _LiveAnalysisConsoleState();
}

class _LiveAnalysisConsoleState extends State<LiveAnalysisConsole> {
  final List<AnalysisEvent> _events = [];
  final ScrollController _scrollController = ScrollController();
  double _progress = 0.0;
  bool _isComplete = false;
  AnalysisSummary? _summary;

  @override
  void initState() {
    super.initState();
    widget.stream.listen((event) {
      if (mounted) {
        setState(() {
          _events.add(event);
          _progress = event.progress;
          if (event.summary != null) {
            _summary = event.summary;
          }
          if (event.phase == 'complete' || event.phase == 'error') {
            _isComplete = true;
          }
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: Color(0xFF00FF41)),
              const SizedBox(width: 8),
              const Text(
                'التحليل الذكي للبيانات',
                style: TextStyle(
                  color: Color(0xFF00FF41),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                '\${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF00FF41),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final e = _events[index];
                  final time = DateTime.now().toString().substring(11, 19);
                  Color textColor = const Color(0xFF00FF41);
                  if (e.phase == 'error') textColor = Colors.redAccent;
                  if (e.message.contains('⚠️')) textColor = Colors.orangeAccent;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '[\$time] ',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "\${e.icon ?? '>'} \${e.message}",
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (_summary != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip('👤 \${_summary!.customersFound} زبائن', _summary!.customersFound > 0),
                _buildChip('🏭 \${_summary!.suppliersFound} موردين', _summary!.suppliersFound > 0),
                _buildChip('📦 \${_summary!.productsFound} منتجات', _summary!.productsFound > 0),
                _buildChip('📸 \${_summary!.imagesFound} صور', _summary!.imagesFound > 0),
              ],
            ),
          ],
          if (_isComplete && _summary != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => widget.onComplete(_summary!),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('متابعة للاستيراد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isGood) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: isGood ? Colors.green.withOpacity(0.3) : Colors.white10,
      side: BorderSide(color: isGood ? Colors.green : Colors.white24),
    );
  }
}
