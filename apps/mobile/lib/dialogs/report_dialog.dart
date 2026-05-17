import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  int _step = 1;
  final Set<int> _selectedOptions = {};
  final TextEditingController _contextCtrl = TextEditingController();
  final TextEditingController _othersCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Store picked images as bytes so it works on both Android and Web
  final List<Uint8List> _imageBytes = [];

  @override
  void dispose() {
    _contextCtrl.dispose();
    _othersCtrl.dispose();
    super.dispose();
  }

  void _toggleOption(int index) => setState(
    () => _selectedOptions.contains(index)
        ? _selectedOptions.remove(index)
        : _selectedOptions.add(index),
  );

  Future<void> _pickImage() async {
    if (_imageBytes.length >= 3) return;
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _imageBytes.add(bytes));
  }

  void _removeImage(int index) => setState(() => _imageBytes.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: _step == 3 ? 32 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_step < 3) ...[_buildHeader(), const SizedBox(height: 12)],
                if (_step == 1) _buildStep1(),
                if (_step == 2) _buildStep2(),
                if (_step == 3) _buildStep3(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'Report',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 1: Choose reason ─────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      children: [
        const Text(
          "we'll review within 24h. you\ncan also block them after.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 16),
        _checkItem(0, 'Harassment or Bullying'),
        _checkItem(1, 'Spam & Scams'),
        _checkItem(2, 'Exposing private identifying\ninformation'),
        _checkItem(3, 'Others', othersField: true),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _btn(
                'Cancel',
                gray: true,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _btn(
                'Next',
                onTap: _selectedOptions.isEmpty
                    ? null
                    : () => setState(() => _step = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2: Additional context + images ───────────────────────────────────
  Widget _buildStep2() {
    final charCount = _contextCtrl.text.length;
    return Column(
      children: [
        // Additional context
        _inputCard(
          label: 'Additional Context',
          trailing: '$charCount/200',
          child: TextField(
            controller: _contextCtrl,
            maxLines: 4,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Type here..',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              counterText: '',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Attach images
        _inputCard(
          label: 'Attach images',
          trailing: '${_imageBytes.length}/3',
          child: _buildImagePicker(),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _btn(
                'Back',
                gray: true,
                onTap: () => setState(() => _step = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _btn('Submit', onTap: () => setState(() => _step = 3)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing thumbnails
        ..._imageBytes.asMap().entries.map((entry) {
          final i = entry.key;
          final bytes = entry.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        // Add button (show only when < 3 images)
        if (_imageBytes.length < 3)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Colors.grey,
                    size: 28,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add photo',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Step 3: Thank you ─────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      children: [
        const Text(
          'Thank you For Your Report',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'We will investigate and take\naction as soon as possible.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.3,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 130,
            height: 42,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDEF1C2),
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFC8C3BE), width: 1),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared: checkbox row ──────────────────────────────────────────────────
  Widget _checkItem(int index, String title, {bool othersField = false}) {
    final bool isSelected = _selectedOptions.contains(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? Colors.black38
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _toggleOption(index),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black87 : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.black87 : Colors.black38,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (othersField && isSelected) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _othersCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type here..',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.black38),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Shared: labeled input card ────────────────────────────────────────────
  Widget _inputCard({
    required String label,
    required String trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ── Shared: button ────────────────────────────────────────────────────────
  Widget _btn(String text, {bool gray = false, VoidCallback? onTap}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: gray
              ? const Color(0xFFE8E8E8)
              : const Color(0xFFDEF1C2),
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFFE8E8E8),
          disabledForegroundColor: Colors.black38,
          elevation: onTap != null ? 1 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: gray ? Colors.transparent : const Color(0xFFC7D2B5),
            ),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
