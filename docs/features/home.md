# Feature: home

Navigation hub. No domain or data layers — thin presentation only.

## File Map

```
features/home/
└── presentation/
    └── screens/home_screen.dart    HomeScreen (StatelessWidget) — stub/dev placeholder
```

## Notes

- Production `HomeScreen` is in `screens/home_screen.dart` (ConsumerStatefulWidget), imported by `main.dart:17`
- `features/home/presentation/screens/home_screen.dart` is a stub (StatelessWidget) — not used in production routes
- No providers, no domain, no data layers in this feature
