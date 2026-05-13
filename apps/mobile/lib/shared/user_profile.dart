import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfileState {
  final String username;
  final String interest;

  const UserProfileState({this.username = 'Somtum', this.interest = ''});

  UserProfileState copyWith({String? username, String? interest}) =>
      UserProfileState(
        username: username ?? this.username,
        interest: interest ?? this.interest,
      );
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  @override
  UserProfileState build() => const UserProfileState();

  void setUsername(String username) =>
      state = state.copyWith(username: username);

  void setInterest(String interest) =>
      state = state.copyWith(interest: interest);

  void update({required String username, required String interest}) =>
      state = UserProfileState(username: username, interest: interest);
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
      UserProfileNotifier.new,
    );
