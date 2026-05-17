import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfileState {
  final String username;
  final String interest;
  final String thought;

  const UserProfileState({
    this.username = 'Somtum',
    this.interest = '',
    this.thought = '',
  });

  UserProfileState copyWith({
    String? username,
    String? interest,
    String? thought,
  }) => UserProfileState(
    username: username ?? this.username,
    interest: interest ?? this.interest,
    thought: thought ?? this.thought,
  );
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  @override
  UserProfileState build() => const UserProfileState();

  void setUsername(String username) =>
      state = state.copyWith(username: username);

  void setInterest(String interest) =>
      state = state.copyWith(interest: interest);

  void setThought(String thought) => state = state.copyWith(thought: thought);

  void update({required String username, required String interest}) =>
      state = UserProfileState(
        username: username,
        interest: interest,
        thought: state.thought,
      );
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
      UserProfileNotifier.new,
    );
