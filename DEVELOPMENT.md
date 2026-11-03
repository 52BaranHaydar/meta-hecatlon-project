# Local development

## OpenRouteService

The local `secret.json` file is ignored by Git. Add your OpenRouteService key
there using the variable name shown in `secret.example.json`:

```json
{
  "OPENROUTESERVICE_API_KEY": "your-key"
}
```

In VS Code, choose one of the `Afet Destek` launch configurations and press F5.
The launch configurations load `secret.json` automatically. From a terminal,
run the app with:

```powershell
flutter run --dart-define-from-file=secret.json
```

Do not commit or share `secret.json`. A key passed to a Flutter client is still
included in the client build and can be extracted; use a server-side proxy
before publishing the app.
