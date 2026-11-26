set -euo pipefail

mkdir -p integration-artifacts
status=0

flutter test integration_test/payment_journey_test.dart -d emulator-5554 --flavor dev --dart-define-from-file=config/dev.json --dart-define=SENTRY_DSN= --no-pub --reporter expanded 2>&1 | tee integration-artifacts/journey.log || status=$?

screenshot_path="$(sed -n 's/.*INTEGRATION_SCREENSHOT=//p' integration-artifacts/journey.log | tail -n 1 | tr -d '\r')"

if [ -n "$screenshot_path" ]; then
  adb exec-out run-as za.co.kgomotsonthuping.ronditrack.dev cat "$screenshot_path" > integration-artifacts/cycle-paid.png
elif [ "$status" -eq 0 ]; then
  echo "The journey did not report a screenshot."
  status=1
fi

exit "$status"