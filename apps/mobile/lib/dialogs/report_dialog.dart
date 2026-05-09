import 'package:flutter/material.dart';

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  int _step = 1;
  final Set<int> _selectedOptions = {};
  final TextEditingController _contextCtrl = TextEditingController();

  @override
  void dispose() {
    _contextCtrl.dispose();
    super.dispose();
  }

  void _toggleOption(int index) {
    setState(() {
      if (_selectedOptions.contains(index)) {
        _selectedOptions.remove(index);
      } else {
        _selectedOptions.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_step < 3)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'Report',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close,
                              size: 28, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
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

  Widget _buildStep1() {
    return Column(
      children: [
        const Text(
          "we'll review within 24h. you\ncan also block them after.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.3),
        ),
        const SizedBox(height: 20),
        _checkItem(0, 'Harassment or Bullying'),
        _checkItem(1, 'Spam & Scams'),
        _checkItem(2, 'Exposing private identifying\ninformation'),
        _checkItem(3, 'Others', hasTextField: true),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                child: _buildButton('Cancel',
                    isGray: true, onTap: () => Navigator.pop(context))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildButton('Next',
                    onTap: _selectedOptions.isEmpty
                        ? null
                        : () => setState(() => _step = 2))),
          ],
        )
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        _buildInputContainer(
          label: 'Additional Context',
          trailing: '/200',
          child: TextField(
            controller: _contextCtrl,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Type here..',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildInputContainer(
          label: 'Attach images',
          trailing: '0/3',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: const Column(
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text('Tap to add photo',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
                child: _buildButton('Back',
                    isGray: true, onTap: () => setState(() => _step = 1))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildButton('Submit',
                    onTap: () => setState(() => _step = 3))),
          ],
        )
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Thank you For Your Report',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const Text(
          'We will investigate and take\naction as soon as possible.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
        ),
        const SizedBox(height: 32),
        _buildButton('Done',
            width: 140, onTap: () => Navigator.pop(context)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _checkItem(int index, String title, {bool hasTextField = false}) {
    bool isSelected = _selectedOptions.contains(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _toggleOption(index),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(6),
                      color:
                          isSelected ? Colors.black : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            if (hasTextField && isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Type here..',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          const BorderSide(color: Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          const BorderSide(color: Colors.black12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputContainer(
      {required String label,
      required String trailing,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(trailing,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildButton(String text,
      {bool isGray = false, VoidCallback? onTap, double? width}) {
    return SizedBox(
      width: width,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isGray ? const Color(0xFFE0E0E0) : const Color(0xFFDEF1C2),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: isGray
                    ? Colors.transparent
                    : const Color(0xFFC7D2B5)),
          ),
        ),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 15)),
      ),
    );
  }
}
