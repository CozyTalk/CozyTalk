import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/friend.dart';

// ─── Public helpers called from FriendsScreen ───────────────────────────────

void showFriendProfileDialog({
  required BuildContext context,
  required Friend friend,
  required void Function(String newNote) onNoteSaved,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _FriendProfileDialog(friend: friend, onNoteSaved: onNoteSaved),
  );
}

void showRemoveConfirmDialog({
  required BuildContext context,
  required Friend friend,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _RemoveConfirmDialog(friendName: friend.name, onConfirm: onConfirm),
  );
}

// ─── Profile popup (view + edit mode) ───────────────────────────────────────

class _FriendProfileDialog extends StatefulWidget {
  final Friend friend;
  final void Function(String) onNoteSaved;

  const _FriendProfileDialog({required this.friend, required this.onNoteSaved});

  @override
  State<_FriendProfileDialog> createState() => _FriendProfileDialogState();
}

class _FriendProfileDialogState extends State<_FriendProfileDialog> {
  static const int _maxNote = 20;
  late final TextEditingController _noteCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.friend.name);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _startEdit() => setState(() => _editing = true);

  void _cancel() {
    setState(() {
      _noteCtrl.text = widget.friend.name;
      _editing = false;
    });
  }

  void _save() {
    final trimmed = _noteCtrl.text.trim();
    if (trimmed.isNotEmpty) widget.onNoteSaved(trimmed);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + Username / Note ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),
                    Expanded(child: _buildInfoColumn()),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Interest ──
                _buildInterestSection(),
                // ── Edit-mode buttons ──
                if (_editing) ...[
                  const SizedBox(height: 20),
                  _buildEditButtons(),
                ],
              ],
            ),
            // ── X close ──
            Positioned(
              top: -10,
              right: -10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 22, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ──
  Widget _buildAvatar() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: widget.friend.avatar.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                widget.friend.avatar,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, color: Colors.grey, size: 50),
              ),
            )
          : const Icon(Icons.person, color: Colors.grey, size: 50),
    );
  }

  // ── Username + Note fields ──
  Widget _buildInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username
        const Text('Username',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 2),
        Text(widget.friend.username,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        // Note label row
        Row(
          children: [
            const Text('Note',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: _startEdit,
              child: const Icon(Icons.edit, size: 15, color: Colors.black87),
            ),
            if (_editing) ...[
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _noteCtrl,
                builder: (_, val, __) => Text(
                  '${val.text.length}/$_maxNote',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Note value or input
        if (!_editing)
          Text(widget.friend.name,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
        else
          SizedBox(
            height: 38,
            child: TextField(
              controller: _noteCtrl,
              maxLength: _maxNote,
              buildCounter: (_, {required currentLength,
                    required isFocused,
                    maxLength}) =>
                  null,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.brownDeep, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Interest section ──
  Widget _buildInterestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Interest',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          widget.friend.interest.isNotEmpty ? widget.friend.interest : '—',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ── Cancel / Save buttons ──
  Widget _buildEditButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PillButton(
          label: 'Cancel',
          bgColor: Colors.grey.shade200,
          textColor: Colors.black87,
          onTap: _cancel,
        ),
        const SizedBox(width: 12),
        _PillButton(
          label: 'save',
          bgColor: AppColors.greenLight,
          textColor: Colors.black87,
          onTap: _save,
        ),
      ],
    );
  }
}

// ─── Remove confirmation dialog ──────────────────────────────────────────────

class _RemoveConfirmDialog extends StatelessWidget {
  final String friendName;
  final VoidCallback onConfirm;

  const _RemoveConfirmDialog(
      {required this.friendName, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Remove "$friendName"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
            ),
            const SizedBox(height: 12),
            // Body
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                children: [
                  const TextSpan(text: 'Are you sure you want to remove\n'),
                  TextSpan(
                    text: '"$friendName"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' from your friends'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PillButton(
                  label: 'Cancel',
                  bgColor: Colors.grey.shade200,
                  textColor: Colors.black87,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                _PillButton(
                  label: 'Remove',
                  bgColor: AppColors.redOrange,
                  textColor: Colors.white,
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared pill button ───────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
