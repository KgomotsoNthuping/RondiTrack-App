import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ronditrack/core/state/screen_state.dart';

class FailureNotice extends StatefulWidget {
  const new({required this.state, this.onRetry, super.key});

  final ScreenFailure<Object?> state;
  final VoidCallback? onRetry;

  @override
  State<FailureNotice> createState() => _FailureNoticeState();
}

class _FailureNoticeState extends State<FailureNotice> {
  bool _referenceDismissed = false;

  @override
  void didUpdateWidget(FailureNotice oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state.correlationId != widget.state.correlationId ||
        oldWidget.state.message != widget.state.message) {
      _referenceDismissed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final reference = state.correlationId;

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state.message),
          for (final entry in state.fields.entries)
            for (final message in entry.value)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${entry.key}: $message'),
              ),
          if (reference != null && !_referenceDismissed) ...[
            const SizedBox(height: 12),
            SelectableText('Reference: $reference'),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: reference));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy reference'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _referenceDismissed = true;
                    });
                  },
                  child: const Text('Dismiss reference'),
                ),
              ],
            ),
          ],
          if (state.canRetry && widget.onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.onRetry,
              child: Text(state.retryLabel),
            ),
          ],
        ],
      ),
    );
  }
}
