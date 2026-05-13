import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import '../shared/user_profile.dart';
import 'profile_edit_screen.dart';
import 'blocked_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildCustomAppBar(context),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        // ── Profile Info Card ──
                        _buildCard(
                          padding: const EdgeInsets.all(24),
                          child: Stack(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 18),
                                        child: Center(
                                          child: LayeredAvatar(
                                            boxSize: 62,
                                            moodOverlay: ref.watch(avatarProvider).mood,
                                            accessoryOverlay: ref.watch(avatarProvider).accessory,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Username',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ref.watch(userProfileProvider).username,
                                          style: const TextStyle(fontSize: 15, color: Colors.black),
                                        ),
                                        const SizedBox(height: 18),
                                        const Text(
                                          'Interest',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ref.watch(userProfileProvider).interest,
                                          style: const TextStyle(fontSize: 15, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () async {
                                    final profile = ref.read(userProfileProvider);
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileEditScreen(
                                          currentName: profile.username,
                                          currentInterest: profile.interest,
                                        ),
                                      ),
                                    );
                                    if (result is Map && mounted) {
                                      ref.read(userProfileProvider.notifier).update(
                                        username: result['name'] as String? ?? profile.username,
                                        interest: result['interest'] as String? ?? profile.interest,
                                      );
                                    }
                                  },
                                  child: SvgPicture.asset('assets/images/icons/Edit.svg', width: 24, height: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Email Card ──
                        _buildCard(
                          child: Row(
                            children: const [
                              Text(
                                'Email :', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Sekloso@gmail.com', 
                                style: TextStyle(fontSize: 15, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Blocked Card ──
                        _buildCard(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedScreen())),
                          child: Row(
                            children: const [
                              Text(
                                'Blocked', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Contact us Card ──
                        _buildCard(
                          onTap: () {},
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/icons/Discord.svg',
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF7289DA),
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Contact us', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                              ),
                              const Spacer(),
                              const Text(
                                '@CozyTalk', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        const SizedBox(height: 24),

                        // ── Log out Card ──
                        _buildCard(
                          onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
                          child: Row(
                            children: [
                              SvgPicture.asset('assets/images/icons/LogOut.svg', width: 24, height: 24),
                              const SizedBox(width: 12),
                              const Text(
                                'Log out', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable AppBar & Card ---
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF695959), borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.08), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: SvgPicture.asset('assets/images/icons/Back.svg', width: 26, height: 26),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Profile', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: child,
      ),
    );
  }
}