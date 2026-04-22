// PRESENTATION — Providers
//
// Put state management classes here (ChangeNotifier, Cubit, Bloc, etc.).
// A provider holds UI state and calls domain repositories to fetch or mutate data.
// It must NOT import anything from the data layer directly.
//
// Example (using ChangeNotifier):
//
// import 'package:flutter/foundation.dart';
// import '../../domain/models/example_model.dart';
// import '../../domain/repositories/example_repository.dart';
//
// class ExampleProvider extends ChangeNotifier {
//   final ExampleRepository _repository;
//   List<ExampleModel> items = [];
//   bool isLoading = false;
//
//   ExampleProvider(this._repository);
//
//   Future<void> load() async {
//     isLoading = true;
//     notifyListeners();
//     items = await _repository.getAll();
//     isLoading = false;
//     notifyListeners();
//   }
// }
