# RondiTrack Mobile

## Running it

Use Flutter 3.47.9 with Dart 3.13.7. Open the repository root in VS Code and start devices.

```powershell
flutter run --flavor dev --dart-define-from-file=config/dev.json
flutter run --flavor staging --dart-define-from-file=config/staging.json
flutter run --flavor prod --dart-define-from-file=config/prod.json
```

Each JSON file contains its `APP_FLAVOR` and public `API_BASE_URL`.
Dev uses `http://10.0.2.2:5227` to reach the API from the Android emulator.
The staging and prod `.invalid` addresses are placeholders for their
deployment URLs.

The development backend is the RondiTrack API. Follow its local
PostgreSQL and configuration setup. [API README](https://github.com/KgomotsoNthuping/RondiTrack/blob/feature/assign-9.2/README.md)

Start the API from the API repository root.

```powershell
dotnet run --project .\Api\Api.csproj --launch-profile http
```

On macOS, the same flavour commands select the shared iOS schemes.
If the dev API runs on the same Mac as the iOS simulator, use its
loopback address.

```sh
flutter run --flavor dev --dart-define-from-file=config/dev.json --dart-define=API_BASE_URL=http://127.0.0.1:5227
```