import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

/// Slide-down song panel — rendered inside a Stack below the header.
class SongPanelBody extends StatefulWidget {
  final VoidCallback onClose;

  const SongPanelBody({super.key, required this.onClose});

  @override
  State<SongPanelBody> createState() => _SongPanelBodyState();
}

class _SongPanelBodyState extends State<SongPanelBody>
    with SingleTickerProviderStateMixin {
  String _nowPlaying =
      'ALIE BLACKCOBRA - มือเปล่า (PUT THE GUN DOWN) (Lyric Video)';
  final List<String> _queue = [
    'Jeff Satur - ของขวัญปีใหม่ (Golden Night)【Official Music Video】',
  ];
  final TextEditingController _inputCtrl = TextEditingController();
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _addSong() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _queue.add(text));
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brownDeep,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Now playing ──
          const Text(
            'Now playing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _nowPlayingCard(),
          const SizedBox(height: 18),
          // ── Queue ──
          const Text(
            'Queue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _queueCard(),
          const SizedBox(height: 14),
          // ── Input ──
          _inputRow(),
        ],
      ),
    );
  }

  Widget _nowPlayingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _spinCtrl,
            child: SvgPicture.asset(
              'assets/images/icons/musicdisk.svg',
              width: 44,
              height: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _nowPlaying.isEmpty ? '—' : _nowPlaying,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _xBtn(onTap: () => setState(() => _nowPlaying = '')),
        ],
      ),
    );
  }

  Widget _queueCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _queue.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Center(
                child: Text(
                  'Queue is empty',
                  style: TextStyle(fontSize: 13, color: Colors.black38),
                ),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(
                    _queue.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _queue[i],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _xBtn(
                            onTap: () => setState(() => _queue.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _xBtn({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCCAA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCF5733), width: 1.5),
        ),
        child: const Icon(Icons.close, color: Color(0xFFCF5733), size: 16),
      ),
    );
  }

  Widget _inputRow() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(fontSize: 14),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSong(),
              decoration: InputDecoration(
                hintText: 'Type here..',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _addSong,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFEAC163),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/images/icons/sent.svg',
              width: 24,
              height: 24,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stub kept so any leftover import doesn't break.
class SongDialog extends StatelessWidget {
  const SongDialog({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
