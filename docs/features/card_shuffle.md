# Feature: card_shuffle

Icebreaker question deck with exhaustion-before-repeat guarantees and depth warm-up. State persisted in `SharedPreferences` (maps to `localStorage` on web).

## File Map

```
features/card_shuffle/
├── domain/
│   ├── entities/
│   │   └── icebreaker_question.dart   IcebreakerQuestion (id, text, category, depth, tags)
│   ├── repositories/
│   │   └── card_shuffle_repository.dart  abstract CardShuffleRepository
│   └── usecases/
│       └── draw_card.dart             DrawCard
├── data/
│   ├── datasources/
│   │   └── card_shuffle_datasource.dart  CardShuffleDatasourceImpl (loads JSON + SharedPreferences)
│   ├── models/
│   │   └── icebreaker_question_model.dart  @freezed IcebreakerQuestionModel + toEntity()
│   └── repositories/
│       └── card_shuffle_repository_impl.dart
└── presentation/
    └── providers/
        └── card_shuffle_provider.dart  cardShuffleNotifierProvider, CardShuffleNotifier, CardShuffleState
```

Asset: `assets/icebreaker-questions.json` — 100 questions across 8 categories.

## Providers

| Provider | Type | Purpose |
|---|---|---|
| `cardShuffleNotifierProvider` | `NotifierProvider<CardShuffleNotifier, CardShuffleState>` | Deck state and draw action |

## State

```dart
class CardShuffleState {
  final IcebreakerQuestion? currentQuestion;
  final bool isLoading;
  final String? error;
}
```

## Deck Algorithm

1. **Remaining / seen piles** — all 100 IDs are split into two sets. Each draw moves one ID from `remaining` to `seen`. When `remaining` is empty the `seen` pile is shuffled back into `remaining` and `seen` is cleared.
2. **Depth warm-up** — the first 5 draws (`drawCount < 5`) are restricted to `light` or `medium` depth questions. After the threshold all questions are eligible. If no light/medium questions remain during warm-up, the full remaining pile is used as a fallback.
3. **Each draw is random** — `Random().nextInt(eligible.length)` picks from the eligible subset, not sequentially.
4. **Persistence** — `SharedPreferences` keys: `card_shuffle_remaining`, `card_shuffle_seen`, `card_shuffle_draw_count`. Survives page refreshes on web (maps to `localStorage`).

## Prototype UI

The `_TopicPanel` widget is inserted into `features/chat/presentation/screens/chat_screen.dart` below the message list. It is toggled by an **Icebreaker Topic** icon button (`Icons.style_outlined`) in the `AppBar`. When opened it draws the first card automatically. A **Next Card** button draws subsequent cards.

The panel is prototype / testing only — it is not wired to the server-side message flow.
