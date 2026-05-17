import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/report_type.dart';
import '../providers/report_provider.dart';

class ReportSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String reportedUserId;

  const ReportSheet({
    super.key,
    required this.sessionId,
    required this.reportedUserId,
  });

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _reasonController = TextEditingController();
  final _contextController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportNotifierProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportNotifierProvider);

    ref.listen<ReportState>(reportNotifierProvider, (_, next) {
      if (!next.isSuccess) return;
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _DragHandle(),
            _SheetHeader(onClose: () => Navigator.of(context).pop()),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel("What's the issue?"),
                    const SizedBox(height: 8),
                    _TypeChips(selected: state.selectedType),
                    const SizedBox(height: 20),
                    const _SectionLabel('Reason *'),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Reason for report',
                      child: TextField(
                        controller: _reasonController,
                        maxLength: 500,
                        maxLines: 3,
                        onChanged: (v) => ref
                            .read(reportNotifierProvider.notifier)
                            .setReason(v),
                        decoration: const InputDecoration(
                          hintText:
                              'Briefly describe why you\'re reporting this user…',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel('Additional context (optional)'),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Additional context',
                      child: TextField(
                        controller: _contextController,
                        maxLength: 2000,
                        maxLines: 5,
                        onChanged: (v) => ref
                            .read(reportNotifierProvider.notifier)
                            .setContextText(v),
                        decoration: const InputDecoration(
                          hintText: 'Provide more details…',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel('Screenshots (optional)'),
                        if (state.contextImagePaths.length < 5)
                          Semantics(
                            label: 'Add screenshot',
                            button: true,
                            child: TextButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Add'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (state.contextImagePaths.isNotEmpty)
                      _ImageGrid(
                        paths: state.contextImagePaths,
                        onRemove: (i) => ref
                            .read(reportNotifierProvider.notifier)
                            .removeImage(i),
                      ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Semantics(
                        label: 'Submit report',
                        button: true,
                        child: FilledButton(
                          onPressed: _canSubmit(state) ? _submit : null,
                          child: state.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit Report'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _canSubmit(ReportState state) =>
      !state.isSubmitting &&
      state.selectedType != null &&
      state.reason.trim().isNotEmpty;

  Future<void> _pickImages() async {
    final remaining =
        5 - ref.read(reportNotifierProvider).contextImagePaths.length;
    if (remaining <= 0) return;
    final images = await _picker.pickMultiImage(limit: remaining);
    if (!mounted) return;
    for (final image in images) {
      ref.read(reportNotifierProvider.notifier).addImage(image.path);
    }
  }

  void _submit() {
    ref
        .read(reportNotifierProvider.notifier)
        .submit(
          sessionId: widget.sessionId,
          reportedUserId: widget.reportedUserId,
        );
  }
}

// ── Drag handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Sheet header ──────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
      child: Row(
        children: [
          Text('Report User', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Semantics(
            label: 'Close report sheet',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

// ── Report type chips ─────────────────────────────────────────────────────────

class _TypeChips extends ConsumerWidget {
  final ReportType? selected;

  const _TypeChips({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: ReportType.values.map((type) {
        final isSelected = selected == type;
        return Semantics(
          label: type.displayName,
          selected: isSelected,
          button: true,
          child: FilterChip(
            label: Text(type.displayName),
            selected: isSelected,
            onSelected: (_) =>
                ref.read(reportNotifierProvider.notifier).selectType(type),
          ),
        );
      }).toList(),
    );
  }
}

// ── Image grid ────────────────────────────────────────────────────────────────

class _ImageGrid extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<int> onRemove;

  const _ImageGrid({required this.paths, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(paths.length, (i) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _ImageThumb(path: paths[i]),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Semantics(
                  label: 'Remove image ${i + 1}',
                  button: true,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Image thumbnail (cross-platform) ─────────────────────────────────────────

class _ImageThumb extends StatefulWidget {
  final String path;

  const _ImageThumb({required this.path});

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = XFile(widget.path).readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const _ThumbError(),
          );
        }
        if (snap.hasError) {
          return const _ThumbError();
        }
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

class _ThumbError extends StatelessWidget {
  const _ThumbError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}
