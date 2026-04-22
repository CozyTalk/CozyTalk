// PRESENTATION — Screens
//
// Put full-page widgets here. Each screen corresponds to a route/page.
// A screen takes a provider (or reads it from context) and builds the UI.
// It must NOT import from the data layer.
//
// Example:
//
// import 'package:flutter/material.dart';
// import '../providers/example_provider.dart';
//
// class ExampleScreen extends StatefulWidget {
//   final ExampleProvider provider;
//   const ExampleScreen({super.key, required this.provider});
//
//   @override
//   State<ExampleScreen> createState() => _ExampleScreenState();
// }
//
// class _ExampleScreenState extends State<ExampleScreen> {
//   @override
//   void initState() {
//     super.initState();
//     widget.provider.load();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Example')),
//       body: ListenableBuilder(
//         listenable: widget.provider,
//         builder: (context, _) {
//           if (widget.provider.isLoading) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           return ListView(
//             children: widget.provider.items
//                 .map((item) => ListTile(title: Text(item.name)))
//                 .toList(),
//           );
//         },
//       ),
//     );
//   }
// }
