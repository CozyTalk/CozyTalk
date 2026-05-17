import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/app_routes.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/blocked_screen.dart';
import 'screens/dress_up_screen.dart';
import 'screens/mood_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/friend_chat_screen.dart';
import 'screens/choose_room_type_screen.dart';
import 'screens/select_background_screen.dart';
import 'screens/join_room_id_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/finding_room_screen.dart';

// TOGGLE: flip to true for legacy UI home (design preview), false for login flow
const _useMainUI = false;

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (_useMainUI) {
      return MaterialApp(
        title: 'CozyTalk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: AppRoutes.home,
        routes: {
          AppRoutes.home: (_) => const HomeScreen(),
          AppRoutes.notification: (_) => const NotificationScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.blocked: (_) => const BlockedScreen(),
          AppRoutes.dressUp: (_) => const DressUpScreen(),
          AppRoutes.mood: (_) => const MoodScreen(),
          AppRoutes.friends: (_) => const FriendsScreen(),
          AppRoutes.friendChat: (_) => const FriendChatScreen(),
          AppRoutes.chooseRoomType: (_) => const ChooseRoomTypeScreen(),
          AppRoutes.selectBackground: (ctx) {
            final args = ModalRoute.of(ctx)?.settings.arguments as String?;
            return SelectBackgroundScreen(roomType: args);
          },
          AppRoutes.joinRoomId: (_) => const JoinRoomIdScreen(),
          AppRoutes.chatScreen: (_) => const ChatScreen(),
          AppRoutes.groupChatScreen: (_) => const GroupChatScreen(),
        },
      );
    }
    return MaterialApp(
      title: 'CozyTalk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
      routes: {
        AppRoutes.notification: (_) => const NotificationScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.blocked: (_) => const BlockedScreen(),
        AppRoutes.dressUp: (_) => const DressUpScreen(),
        AppRoutes.mood: (_) => const MoodScreen(),
        AppRoutes.friends: (_) => const FriendsScreen(),
        AppRoutes.friendChat: (_) => const FriendChatScreen(),
        AppRoutes.chooseRoomType: (_) => const ChooseRoomTypeScreen(),
        AppRoutes.selectBackground: (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments as String?;
          return SelectBackgroundScreen(roomType: args);
        },
        AppRoutes.joinRoomId: (_) => const JoinRoomIdScreen(),
        AppRoutes.chatScreen: (_) => const ChatScreen(),
        AppRoutes.groupChatScreen: (_) => const GroupChatScreen(),
        AppRoutes.findingRoom: (_) => const FindingRoomScreen(),
      },
    );
  }
}
