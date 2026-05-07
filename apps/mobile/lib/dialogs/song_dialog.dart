import 'package:flutter/material.dart';

class SongDialog extends StatelessWidget {
  const SongDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: const Color(0xFF6B5E5B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Now playing',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.album_outlined,
                      size: 45, color: Colors.black),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                        'ALIE BLACKCOBRA - มือเปล่า (PUT\nTHE GUN DOWN) (Lyric Video)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.3)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCCAA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFCF5733), width: 1.5),
                    ),
                    child: const Icon(Icons.close,
                        color: Color(0xFFCF5733), size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Queue',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _queueItem('1.',
                      'Jeff Satur - ของขวัญปีใหม่ (Golden\nNight) 【Official Music Video】'),
                  const SizedBox(height: 20),
                  _queueItem('2.', ''),
                  const SizedBox(height: 20),
                  _queueItem('3.', ''),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type here..',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAC163),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.send,
                      color: Color(0xFF6B5E5B), size: 28),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _queueItem(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.3)),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCCAA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCF5733), width: 1.5),
          ),
          child: const Icon(Icons.close, color: Color(0xFFCF5733), size: 16),
        ),
      ],
    );
  }
}
