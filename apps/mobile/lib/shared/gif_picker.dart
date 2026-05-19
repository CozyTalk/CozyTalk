import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Mock GIF entries — replace with real Tenor/Giphy API data later
const _mockGifs = [
  _MockGif('Wave', Color(0xFFFFD1DC)),
  _MockGif('LOL', Color(0xFFD1F0FF)),
  _MockGif('Wow', Color(0xFFD4FFD1)),
  _MockGif('Sad', Color(0xFFE8D1FF)),
  _MockGif('Fire', Color(0xFFFFE5D1)),
  _MockGif('Love', Color(0xFFFFD1D1)),
  _MockGif('Win', Color(0xFFFFF9D1)),
  _MockGif('Cute', Color(0xFFD1FFEC)),
  _MockGif('Hype', Color(0xFFFFD1F5)),
  _MockGif('Sleep', Color(0xFFD1E4FF)),
  _MockGif('OMG', Color(0xFFFFECD1)),
  _MockGif('Cool', Color(0xFFD1FFF9)),
];

class _MockGif {
  final String label;
  final Color color;
  const _MockGif(this.label, this.color);
}

/// Show GIF picker bottom sheet.
/// Returns the selected [gifLabel] string, or null if dismissed.
Future<String?> showGifPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GifPickerSheet(),
  );
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet();

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<_MockGif> _filtered = _mockGifs;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _mockGifs
          : _mockGifs.where((g) => g.label.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4A3E3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yellowWarm,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF4A3228),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search GIFs...',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Grid
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No GIFs found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final gif = _filtered[i];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, gif.label),
                          child: Container(
                            decoration: BoxDecoration(
                              color: gif.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  gif.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF4A3228),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'GIF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4A3228),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
