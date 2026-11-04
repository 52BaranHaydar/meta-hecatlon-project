# Afet Destek

:tr Afet durumlarında ihtiyaç sahipleriyle destek sağlayanları buluşturmayı amaçlayan Flutter uygulaması.
:eng A Flutter application designed to connect those in need with those providing support during disasters.

## :tr Uygulamayı çalıştırma

Yaya rotalarını kullanabilmek için OpenRouteService API anahtarınızı yapılandırın:

1. [OpenRouteService](https://openrouteservice.org/) üzerinden bir API anahtarı alın.
2. Proje klasöründeki `secret.example.json` dosyasını `secret.json` adıyla kopyalayın.
3. `secret.json` dosyasını açın ve `OPENROUTESERVICE_API_KEY` değerini kendi API anahtarınızla değiştirin.
4. Uygulamayı aşağıdaki yöntemlerden biriyle başlatın:
   - **VS Code:** `Afet Destek` başlatma yapılandırmalarından birini seçin ve **F5**'e basın. Anahtar dosyası otomatik olarak yüklenir.
   - **Terminal:** Proje klasöründe aşağıdaki komutu çalıştırın:

     ```powershell
     flutter run --dart-define-from-file=secret.json
     ```

Terminal komutunu uygulamayı her yeniden başlattığınızda tekrar çalıştırmanız gerekir. VS Code'da **F5** ile başlatırsanız komutu elle girmeniz gerekmez.

`secret.json` gizli bilgiler içerir; bu dosyayı paylaşmayın veya Git'e eklemeyin. Flutter istemci uygulamasına eklenen API anahtarları yayımlanan uygulamalardan çıkarılabilir. Üretim ortamında anahtarı sunucu tarafında saklayın ve istekleri bir sunucu vekili üzerinden yönlendirin.

## :eng Running the app

Configure your OpenRouteService API key to use walking directions:

1. Get an API key from [OpenRouteService](https://openrouteservice.org/).
2. Copy `secret.example.json` in the project directory and name the copy `secret.json`.
3. Open `secret.json` and replace the `OPENROUTESERVICE_API_KEY` value with your API key.
4. Start the app using either of the following methods:
   - **VS Code:** Select one of the `Afet Destek` launch configurations and press **F5**. The key file is loaded automatically.
   - **Terminal:** Run the following command from the project directory:

     ```powershell
     flutter run --dart-define-from-file=secret.json
     ```

When using the terminal, run the command again each time you restart the app. In VS Code, press **F5** to launch the app without entering the command manually.

`secret.json` contains sensitive information; do not share it or add it to Git. API keys included in a Flutter client app can be extracted from published builds. For production, store the key on a server and route requests through a server-side proxy.
