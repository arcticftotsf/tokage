import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const TokageApp());

class TokageApp extends StatelessWidget {
  const TokageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tokage',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const MatchPage(),
    );
  }
}

enum CardType { yellow, red }

enum Team { home, away }

class CardRecord {
  const CardRecord({
    required this.type,
    required this.team,
    required this.number,
    required this.elapsed,
  });

  final CardType type;
  final Team team;
  final int number;
  final Duration elapsed;
}

String formatElapsed(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class MatchPage extends StatefulWidget {
  const MatchPage({super.key});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  DateTime? _startedAt;
  Timer? _timer;
  final List<CardRecord> _records = [];

  bool get _started => _startedAt != null;

  // 経過時間は「今の時刻 - 開始時刻」で計算する（バックグラウンドでもずれない）
  Duration get _elapsed =>
      _started ? DateTime.now().difference(_startedAt!) : Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _startedAt = DateTime.now();
      _records.clear();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('試合をリセットしますか？'),
        content: const Text('記録したカードもすべて消えます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _timer?.cancel();
    setState(() {
      _startedAt = null;
      _records.clear();
    });
  }

  Future<void> _addCard(CardType type) async {
    // カードを出した時刻は「ボタンを押した瞬間」で確定させる
    final elapsed = _elapsed;
    final input = await showDialog<_CardInput>(
      context: context,
      builder: (context) => _NumberDialog(type: type),
    );
    if (input == null || !mounted) return;
    setState(() {
      _records.insert(
        0,
        CardRecord(
          type: type,
          team: input.team,
          number: input.number,
          elapsed: elapsed,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('tokage')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                formatElapsed(_elapsed),
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              _started
                  ? OutlinedButton(
                      onPressed: _confirmReset,
                      child: const Text('リセット'),
                    )
                  : FilledButton(
                      onPressed: _start,
                      child: const Text('試合開始'),
                    ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CardButton(
                      label: 'イエロー',
                      background: Colors.yellow,
                      foreground: Colors.black,
                      onPressed:
                          _started ? () => _addCard(CardType.yellow) : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CardButton(
                      label: 'レッド',
                      background: Colors.red,
                      foreground: Colors.white,
                      onPressed: _started ? () => _addCard(CardType.red) : null,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: _records.isEmpty
                    ? const Center(child: Text('カードの記録はまだありません'))
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, i) => _RecordTile(_records[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile(this.record);

  final CardRecord record;

  @override
  Widget build(BuildContext context) {
    final isYellow = record.type == CardType.yellow;
    return ListTile(
      leading: Container(
        width: 24,
        height: 34,
        decoration: BoxDecoration(
          color: isYellow ? Colors.yellow : Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text('#${record.number}'),
      subtitle: Text(record.team == Team.home ? 'ホーム' : 'アウェイ'),
      trailing: Text(
        formatElapsed(record.elapsed),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _CardInput {
  const _CardInput(this.team, this.number);

  final Team team;
  final int number;
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({required this.type});

  final CardType type;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  final _controller = TextEditingController();
  Team _team = Team.home;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final number = int.tryParse(_controller.text);
    if (number == null) return;
    Navigator.pop(context, _CardInput(_team, number));
  }

  @override
  Widget build(BuildContext context) {
    final isYellow = widget.type == CardType.yellow;
    return AlertDialog(
      title: Text(isYellow ? 'イエローカード' : 'レッドカード'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<Team>(
            segments: const [
              ButtonSegment(value: Team.home, label: Text('ホーム')),
              ButtonSegment(value: Team.away, label: Text('アウェイ')),
            ],
            selected: {_team},
            onSelectionChanged: (s) => setState(() => _team = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: const InputDecoration(labelText: '背番号'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('記録')),
      ],
    );
  }
}