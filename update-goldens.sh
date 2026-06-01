#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/apps/mobile"

echo "Regenerating golden baselines..."

flutter test \
  test/widgets/cozy_card_golden_test.dart \
  test/widgets/offline_card_golden_test.dart \
  test/widgets/offline_chip_golden_test.dart \
  test/widgets/pill_button_golden_test.dart \
  --update-goldens --reporter expanded

echo ""
echo "Done. Review the updated PNGs in test/widgets/goldens/ then commit them alongside your UI change."
