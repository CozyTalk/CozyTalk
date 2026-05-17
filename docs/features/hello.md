# Feature: hello

Canonical Clean Architecture reference implementation. Calls the `helloWorld` CF echo and displays the response.

## File Map

```
features/hello/
├── domain/
│   ├── entities/hello_message.dart         HelloMessage
│   ├── repositories/hello_repository.dart  abstract HelloRepository
│   └── usecases/call_hello.dart            CallHello
├── data/
│   ├── datasources/hello_datasource.dart   HelloDatasourceImpl
│   ├── models/hello_message_model.dart     @freezed HelloMessageModel + toEntity()
│   └── repositories/hello_repository_impl.dart
└── presentation/
    ├── providers/hello_provider.dart       helloNotifierProvider, HelloNotifier, HelloState
    └── screens/hello_screen.dart           HelloScreen (ConsumerStatefulWidget)
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `helloNotifierProvider` | `NotifierProvider<HelloNotifier, HelloState>` | entry point for screens |

## State

`HelloState` — holds `message` (String?), `isLoading` (bool), `error` (String?)

## Notes

- Used by `_AuthRouter` when `_useMainUI = false` and auth is `authenticated`
- The `helloWorld` CF in `functions/src/index.ts` is the backend; kept for smoke testing
- Copy this feature as the starting point for any new feature
