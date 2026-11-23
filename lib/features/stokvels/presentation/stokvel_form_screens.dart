import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/stokvels/application/cycle_editor.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_workflow_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_forms.dart';

class CreateStokvelScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStateProvider);

    if (session is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _CreateStokvelForm(key: ValueKey(session.identity.userId));
  }
}

class _CreateStokvelForm extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<_CreateStokvelForm> createState() =>
      _CreateStokvelScreenState();
}

class _CreateStokvelScreenState extends ConsumerState<_CreateStokvelForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _monthly = TextEditingController();
  final _current = TextEditingController(text: '1');
  final _total = TextEditingController();
  final _rules = TextEditingController();

  Map<String, List<String>> _errors = {};
  String? _message;
  bool _busy = false;
  bool _created = false;

  @override
  void dispose() {
    for (final field in [_name, _monthly, _current, _total, _rules]) {
      field.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionStateProvider);

    if (session is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final workflow = ref.watch(
      stokvelWorkflowProvider((
        userId: session.identity.userId,
        sessionId: session.sessionId,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create stokvel'),
        leading: BackButton(onPressed: () => context.go('/stokvels')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _field(
                  _name,
                  'name',
                  'Stokvel name',
                  validator: (text) {
                    if (text == null || text.trim().isEmpty) {
                      return 'Enter a stokvel name.';
                    }

                    return text.trim().length > 50
                        ? 'Use 50 characters or fewer.'
                        : null;
                  },
                ),
                _field(
                  _monthly,
                  'monthlyContribution',
                  'Monthly contribution in rands',
                  validator: moneyError,
                  money: true,
                ),
                _field(
                  _current,
                  'currentPeriod',
                  'Current period',
                  validator: positiveIntegerError,
                  number: true,
                ),
                _field(
                  _total,
                  'totalPeriods',
                  'Total periods',
                  validator: positiveIntegerError,
                  number: true,
                ),
                _field(
                  _rules,
                  'rules',
                  'Rules',
                  validator: (text) => (text?.length ?? 0) > 1000
                      ? 'Use 1000 characters or fewer.'
                      : null,
                  lines: 4,
                ),
                if (_message != null) ...[
                  Semantics(liveRegion: true, child: Text(_message!)),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _busy || _created
                      ? null
                      : () async {
                          setState(() {
                            _errors = {};
                            _message = null;
                          });

                          if (!_form.currentState!.validate()) {
                            return;
                          }

                          final current = int.parse(_current.text.trim());
                          final total = int.parse(_total.text.trim());

                          if (current > total) {
                            setState(() {
                              _errors = {
                                'currentPeriod': [
                                  'Current period cannot exceed total periods.',
                                ],
                              };
                            });
                            return;
                          }

                          final parsed = parseRand(_monthly.text) as ParsedRand;

                          setState(() => _busy = true);

                          try {
                            await workflow.create((
                              name: _name.text.trim(),
                              monthlyContribution: parsed.cents,
                              currentPeriod: current,
                              totalPeriods: total,
                              rules: _rules.text.trim().isEmpty
                                  ? null
                                  : _rules.text.trim(),
                            ));

                            if (mounted) {
                              setState(() {
                                _created = true;
                                _message =
                                    'Stokvel created. It will appear in your '
                                    'list when your membership is active.';
                              });
                            }
                          } on Object catch (error) {
                            if (mounted) {
                              setState(() {
                                if (error is ValidationFailure) {
                                  _errors = error.errors;
                                }

                                _message = formFailure(error);
                              });
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _busy = false);
                            }
                          }
                        },
                  child: Text(_busy ? 'Creating…' : 'Create stokvel'),
                ),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String name,
    String label, {
    required String? Function(String?) validator,
    bool money = false,
    bool number = false,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('create-$name'),
        controller: controller,
        enabled: !_busy && !_created,
        maxLines: lines,
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : number
            ? TextInputType.number
            : null,
        decoration: InputDecoration(
          labelText: label,
          errorText: serverFieldError(_errors, name),
        ),
        validator: validator,
      ),
    );
  }
}

class EditCycleScreen extends ConsumerWidget {
  const new({required this.stokvelId, required this.cycleId, super.key});

  final String stokvelId;
  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStateProvider);

    if (session is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _EditCycleFormScreen(
      key: ValueKey((session.identity.userId, stokvelId, cycleId)),
      stokvelId: stokvelId,
      cycleId: cycleId,
    );
  }
}

class _EditCycleFormScreen extends ConsumerStatefulWidget {
  const new({required this.stokvelId, required this.cycleId, super.key});

  final String stokvelId;
  final String cycleId;

  @override
  ConsumerState<_EditCycleFormScreen> createState() => _EditCycleScreenState();
}

class _EditCycleScreenState extends ConsumerState<_EditCycleFormScreen> {
  Future<EditableCycle>? _initial;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionStateProvider);

    if (session is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final workflow = ref.watch(
      stokvelWorkflowProvider((
        userId: session.identity.userId,
        sessionId: session.sessionId,
      )),
    );

    _initial ??= workflow.initialCycle(widget.stokvelId, widget.cycleId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit cycle'),
        leading: BackButton(
          onPressed: () => context.go(
            Uri(
              pathSegments: [
                '',
                'stokvels',
                widget.stokvelId,
                'cycles',
                widget.cycleId,
              ],
            ).toString(),
          ),
        ),
      ),
      body: FutureBuilder<EditableCycle>(
        future: _initial,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formFailure(snapshot.error!)),
                  TextButton(
                    onPressed: () => setState(() {
                      _initial = workflow.initialCycle(
                        widget.stokvelId,
                        widget.cycleId,
                      );
                    }),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          final initial = snapshot.data;

          if (initial == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return _CycleForm(
            key: ValueKey(widget.cycleId),
            initial: initial,
            loadLatest: () =>
                workflow.latestCycle(widget.stokvelId, widget.cycleId),
            save: (number, target, version) => workflow.saveCycle(
              widget.stokvelId,
              widget.cycleId,
              number,
              target,
              version,
            ),
          );
        },
      ),
    );
  }
}

class _CycleForm extends StatefulWidget {
  const new({
    required this.initial,
    required this.loadLatest,
    required this.save,
    super.key,
  });

  final EditableCycle initial;
  final Future<EditableCycle> Function() loadLatest;
  final Future<EditableCycle> Function(int, Cents, int) save;

  @override
  State<_CycleForm> createState() => _CycleFormState();
}

class _CycleFormState extends State<_CycleForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _target;
  late final CycleEditor _editor;

  bool _saved = false;

  @override
  void initState() {
    super.initState();

    _number = TextEditingController(text: widget.initial.number.toString());
    _target = TextEditingController(text: widget.initial.target.formatRand());

    _editor = CycleEditor(
      initial: widget.initial,
      loadLatest: () => widget.loadLatest(),
      save: (number, target, version) => widget.save(number, target, version),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _target.dispose();
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _editor,
      builder: (context, child) {
        final failure = _editor.failure;
        final errors = failure is ValidationFailure
            ? failure.errors
            : const <String, List<String>>{};

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _editor.saving ? 'Proposed changes' : 'Latest saved values',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Cycle ${_editor.displayed.number}'),
                  Text('Target ${_editor.displayed.target.formatRand()}'),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('edit-cycle-number'),
                    controller: _number,
                    enabled: !_editor.saving,
                    keyboardType: TextInputType.number,
                    validator: positiveIntegerError,
                    decoration: InputDecoration(
                      labelText: 'Cycle number',
                      errorText: serverFieldError(errors, 'cycleNumber'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('edit-cycle-target'),
                    controller: _target,
                    enabled: !_editor.saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: moneyError,
                    decoration: InputDecoration(
                      labelText: 'Target in rands',
                      errorText: serverFieldError(errors, 'targetAmount'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_editor.requiresReview) ...[
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        'Someone else changed this cycle. Your entries are '
                        'kept. Review the latest values before saving again.',
                      ),
                    ),
                    if (_editor.canAcceptLatest)
                      TextButton(
                        onPressed: _editor.acceptLatest,
                        child: const Text(
                          'Keep my entries and use latest version',
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _editor.reloadLatest,
                        child: const Text('Reload latest values'),
                      ),
                  ] else if (failure != null)
                    Semantics(liveRegion: true, child: Text(failure.message)),
                  if (_editor.reloadFailure != null)
                    Text(_editor.reloadFailure!.message),
                  if (_saved)
                    Semantics(
                      liveRegion: true,
                      child: const Text('Cycle saved.'),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _editor.saving || _editor.requiresReview
                        ? null
                        : () async {
                            if (!_form.currentState!.validate()) {
                              return;
                            }

                            final amount =
                                parseRand(_target.text) as ParsedRand;

                            final saved = await _editor.submit(
                              int.parse(_number.text.trim()),
                              amount.cents,
                            );

                            if (mounted) {
                              setState(() => _saved = saved);
                            }
                          },
                    child: Text(_editor.saving ? 'Saving…' : 'Save cycle'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String? moneyError(String? input) {
  return switch (parseRand(input ?? '')) {
    InvalidRand(:final reason) => reason,
    ParsedRand(:final cents) when cents.value <= 0 =>
      'Enter an amount greater than zero.',
    ParsedRand() => null,
  };
}

String? positiveIntegerError(String? input) {
  final text = input?.trim() ?? '';
  final value = int.tryParse(text);

  return !RegExp(r'^[1-9]\d*$').hasMatch(text) ||
          value == null ||
          value > 2147483647
      ? 'Enter a positive whole number.'
      : null;
}

String? serverFieldError(Map<String, List<String>> errors, String name) {
  for (final entry in errors.entries) {
    if (entry.key.split('.').last.toLowerCase() == name.toLowerCase()) {
      return entry.value.join('\n');
    }
  }

  return null;
}

String formFailure(Object error) {
  return error is Failure ? error.message : const ServerFailure().message;
}
