import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n.dart';
import '../models/models.dart';
import '../services/native.dart';
import '../services/store.dart';
import 'widgets.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key, required this.onMeasure});
  final VoidCallback onMeasure;

  IconData _icon(Measurement m) => switch (m.mode) {
        Mode.level => Icons.horizontal_rule,
        Mode.plumb => Icons.vertical_align_bottom,
        Mode.flat => Icons.adjust,
      };

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('Copiat', 'Copied')), duration: const Duration(seconds: 1)));
    }
  }

  Future<void> _note(BuildContext context, Measurement m) async {
    final c = TextEditingController(text: m.note);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Notă', 'Note')),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(hintText: tr('ex. raft bucătărie', 'e.g. kitchen shelf')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Anulează', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('Salvează', 'Save'))),
        ],
      ),
    );
    if (v != null) {
      m.note = v.trim();
      store.save();
    }
  }

  void _sheet(BuildContext context, Measurement m) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(measurementValue(m), style: Theme.of(ctx).textTheme.displaySmall),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('${measurementDetail(m)}\n${dateTimeText(m.time)}',
                textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(m.note.isEmpty ? tr('Adaugă notă', 'Add note') : tr('Editează nota', 'Edit note')),
            onTap: () {
              Navigator.pop(ctx);
              _note(context, m);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(tr('Copiază', 'Copy')),
            onTap: () {
              Navigator.pop(ctx);
              _copy(context, measurementText(m));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(tr('Distribuie', 'Share')),
            onTap: () {
              Navigator.pop(ctx);
              Native.share(measurementText(m));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
            title: Text(tr('Șterge', 'Delete'), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () {
              Navigator.pop(ctx);
              store.removeMeasurement(m.id);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Ștergi toate măsurătorile?', 'Delete all measurements?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Anulează', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Șterge tot', 'Delete all'))),
        ],
      ),
    );
    if (ok == true) {
      store.measurements.clear();
      store.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.measurements;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Măsurători salvate', 'Saved measurements')),
            actions: [
              if (list.isNotEmpty) ...[
                IconButton(
                  tooltip: tr('Distribuie tot', 'Share all'),
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => Native.share(list.map(measurementText).join('\n\n')),
                ),
                PopupMenuButton<int>(
                  onSelected: (v) {
                    if (v == 0) _copy(context, list.map(measurementText).join('\n\n'));
                    if (v == 1) _clearAll(context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(tr('Copiază tot', 'Copy all'))),
                    PopupMenuItem(value: 1, child: Text(tr('Șterge tot', 'Delete all'))),
                  ],
                ),
              ],
            ],
          ),
          body: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bookmarks_outlined, size: 56, color: cs.outline),
                      const SizedBox(height: 14),
                      Text(tr('Nicio măsurătoare salvată', 'No saved measurements'), style: t.titleMedium),
                      const SizedBox(height: 6),
                      Text(tr('Apasă „Salvează” când măsori. Se păstrează oricâte.', 'Tap "Save" while measuring. Keep as many as you like.'),
                          textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 18),
                      FilledButton.tonalIcon(
                          onPressed: onMeasure, icon: const Icon(Icons.straighten), label: Text(tr('Măsoară', 'Measure'))),
                    ]),
                  ),
                )
              : MaxWidth(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = list[i];
                      return Material(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _sheet(context, m),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Row(children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                child: Icon(_icon(m), color: cs.onPrimaryContainer),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (m.note.isNotEmpty)
                                    Text(m.note, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(measurementDetail(m), maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  Text(dateTimeText(m.time), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ]),
                              ),
                              Text(measurementValue(m),
                                  style: t.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                              IconButton(
                                tooltip: tr('Copiază', 'Copy'),
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () => _copy(context, measurementText(m)),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
