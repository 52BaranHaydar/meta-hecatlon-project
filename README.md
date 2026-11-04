# English

Afet Destek (Disaster Relief) is a Flutter application intended to connect
people affected by disasters with relief locations, logistics teams, and
crisis coordinators. It brings citizen reports, aid-location information,
and shipment tracking into role-based workflows.

> **Important:** This project is a prototype. Map locations and sample reports
> may contain demo data, and AI output can be inaccurate or incomplete. The
> app is not a replacement for official emergency services, AFAD, or the
> 112 Emergency Call Center. Call **112** in an urgent or life-threatening
> situation.

## Features

- **Citizens:** Create an account and sign in; submit a needs/disaster report
  with location; review AI-assisted category, urgency, and resource
  suggestions; find assembly areas, tent cities, relief and medical points on
  the map; request walking directions; share safety status and location with
  a safety circle; prepare SMS drafts; and use the SOS siren, vibration, and
  optional camera flashlight.
- **Carriers and logistics:** Create truck or van shipments for water, tents,
  medicine, infant formula, food, or blankets; select a destination; advance
  shipment status; and track destination stock. Stock is updated when a
  delivery is completed.
- **Crisis management:** Review live incoming reports and urgency filters,
  view report locations on the map, track response status, manage relief
  locations and stock, and monitor shipments.
- **Shared experience:** Turkish and English interface, light/dark themes, a
  role-based home screen, disaster map, AI triage, and a Llama-powered
  disaster assistant.
- **Connectivity:** Firestore streams synchronize report, area, and shipment
  data when Firebase is configured. Some reports can be saved as SMS drafts
  while offline; drafts are not sent automatically.

## Stack

Flutter and Dart; Firebase Authentication and Cloud Firestore; `flutter_map`,
`latlong2`, and `geolocator`; OpenRouteService for walking directions; and a
Meta AI/LLM API for the assistant and report classification, with local
fallback behavior in some flows.

## Setup

Install Flutter and Dart (the project specifies Dart `^3.9.2`), then run:

```sh
flutter pub get
```

Copy `secret.example.json` to `secret.json` and configure `META_API_KEY`,
`FIREBASE_API_KEY`, and `OPENROUTESERVICE_API_KEY`. If using your own Firebase
project, update the platform configuration in
[`lib/firebase_options.dart`](lib/firebase_options.dart) as well.

Run the app with:

```sh
flutter run --dart-define-from-file=secret.json
```

In VS Code, choose an `Afet Destek` launch configuration and press **F5**.
Never commit or share `secret.json`. Client-side API keys can be extracted
from published builds; use server-side proxies and restrict keys for
production. See [`DEVELOPMENT.md`](DEVELOPMENT.md) for local setup notes.

## Validation

```sh
flutter analyze
flutter test
```
# Afet Destek | Disaster Relief

Afet Destek, afet anında yardıma ihtiyaç duyan kişileri destek noktaları,
lojistik ekipleri ve kriz yöneticileriyle buluşturmayı hedefleyen Flutter
uygulamasıdır. Vatandaş ihbarlarının değerlendirilmesinden yardım
sevkiyatlarının izlenmesine kadar farklı rollere yönelik akışları tek bir
uygulamada toplar.

> **Önemli:** Bu proje bir prototiptir. Harita alanları ve örnek ihbarlar demo
> verisi içerebilir; yapay zekâ değerlendirmeleri hatalı veya eksik olabilir.
> Uygulama resmî acil yardım kanallarının, AFAD'ın veya 112 Acil Çağrı
> Merkezi'nin yerine geçmez. Acil ve hayati durumlarda **112'yi arayın**.

## Özellikler

### Vatandaş

- E-posta ve şifreyle hesap oluşturma ve oturum açma.
- İhtiyaç veya afet ihbarını konum bilgisiyle iletme; yapay zekâ destekli
  sınıflandırma, öncelik ve kaynak önerilerini görüntüleme.
- Toplanma alanlarını, çadır kentleri, aşevi/yardım noktalarını ve sağlık
  noktalarını haritada inceleme; konuma izin verildiğinde mevcut konumu görme
  ve OpenRouteService ile yaya rotası alma.
- Güvenlik ağı daveti oluşturma veya daveti kabul etme; yakınının son güvenlik
  durumunu, bildirim zamanını ve paylaşılmış konumunu görüntüleme.
- Güvende veya yardıma ihtiyaç duyuyor durumunu paylaşma; kan grubu ve
  yakındaki kişilere gönderilmek üzere SMS taslakları hazırlama.
- SOS ekranında siren, titreşim ve isteğe bağlı kamera flaşıyla dikkat çekme.
  İnternet yokken bazı ihbarlar SMS taslağı olarak kuyrukta saklanabilir.

### Lojistik / taşıyıcı

- Tır veya kamyonetle su, çadır, ilaç, mama, gıda ve battaniye sevkiyatı
  oluşturma.
- Hedef yardım noktasını, araç plakasını ve miktarı belirleme; sevkiyat
  durumunu aşamalı olarak güncelleme.
- Aktif sevkiyatları ve yardım noktalarının stoklarını takip etme. Teslimat
  tamamlandığında ilgili noktanın stoku güncellenir.

### Kriz yönetimi

- Vatandaş ihbarlarını canlı akışta ve aciliyet seviyesine göre inceleme;
  kritik, yüksek öncelikli ve çözülen kayıtları filtreleme.
- İhbarların konumunu haritada açma, müdahale/ekip yönlendirme durumunu
  izleme ve kriz özeti metriklerini görüntüleme.
- Yardım alanları ekleme, alan bilgilerini ve stokları yönetme.
- Sevkiyatları ve yardım noktalarının stoklarını canlı olarak izleme.

### Uygulama genelinde

- Türkçe ve İngilizce arayüz; açık ve koyu tema.
- Rol bazlı ana sayfa, afet/yardım haritası, ihbar analizi ve Llama destekli
  afet asistanı.
- Firebase bağlantısı mevcut olduğunda kullanıcı, ihbar, alan ve sevkiyat
  verileri için bulut senkronizasyonu.

## Teknoloji

- **Flutter / Dart** — mobil, web ve masaüstü uygulama arayüzü.
- **Firebase Authentication** — hesap ve oturum yönetimi.
- **Cloud Firestore** — ihbar, yardım alanı ve sevkiyat verileri için gerçek
  zamanlı veri akışları.
- **flutter_map**, **latlong2** ve **geolocator** — harita, koordinat ve cihaz
  konumu.
- **OpenRouteService** — yaya rotası.
- **Meta AI / LLM API** — afet asistanı ve ihbar sınıflandırma. Canlı servis
  kullanılamadığında bazı akışlarda yerel yedek davranış bulunur.
- **SharedPreferences** — dil/tema tercihleri, yakınlar ve SMS taslak kuyruğu
  gibi cihaz üzerindeki veriler.

## Başlangıç

### Gereksinimler

- Flutter SDK ve Dart SDK (`pubspec.yaml` içindeki Dart sürüm aralığı: `^3.9.2`)
- Geliştirme hedefinize uygun Flutter platform araçları (Android, iOS, web,
  Windows, macOS veya Linux)
- Canlı Firebase, yapay zekâ ve yaya rotası özellikleri için ilgili servis
  yapılandırmaları ve API erişimleri

### Kurulum ve çalıştırma

1. Depoyu klonlayıp proje klasörüne geçin.
2. Bağımlılıkları yükleyin:

   ```sh
   flutter pub get
   ```

3. Örnek yapılandırma dosyasını kopyalayın:

   ```powershell
   Copy-Item secret.example.json secret.json
   ```

   macOS/Linux kabuğunda:

   ```sh
   cp secret.example.json secret.json
   ```

4. `secret.json` içindeki aşağıdaki değerleri kullanacağınız servislerle
   yapılandırın:

   | Anahtar | Kullanım |
   | --- | --- |
   | `META_API_KEY` | Canlı yapay zekâ asistanı ve ihbar sınıflandırması |
   | `FIREBASE_API_KEY` | Firebase uygulama bağlantısı |
   | `OPENROUTESERVICE_API_KEY` | Yaya rotası |

   Firebase platform seçenekleri ayrıca [`lib/firebase_options.dart`](lib/firebase_options.dart)
   içinde tanımlıdır. Kendi Firebase projenizi kullanıyorsanız platform
   yapılandırmasını da o projeye göre güncelleyin.

5. Uygulamayı başlatın:

   ```sh
   flutter run --dart-define-from-file=secret.json
   ```

   VS Code'da `Afet Destek` başlatma yapılandırmalarından birini seçip **F5**'e
   basabilirsiniz; yapılandırmalar `secret.json` dosyasını otomatik yükler.

`secret.json` gizli/özel yapılandırma değerleri içerebilir; dosyayı paylaşmayın
ve Git'e eklemeyin. Bu değerlerin Flutter istemci uygulamasına eklenmesi
yayımlanan uygulamalardan çıkarılabilir. Üretim ortamında sunucu tarafı vekil
kullanın, servis anahtarlarını kısıtlayın ve Firebase güvenlik kurallarını
dağıtımdan önce gözden geçirin. Uygulama, Firebase ve harita/rota servislerine
erişim olmadığında tüm canlı işlevlerin kullanılabilir olacağını garanti etmez.

## Test ve analiz

```sh
flutter analyze
flutter test
```

Testler güvenlik ağı, SMS taslakları ve lojistik akışları gibi bileşenleri
kapsar.

## Proje yapısı

```text
lib/
  constants/   Tema ve uygulama sabitleri
  models/      Kullanıcı, yardım alanı, ihbar ve sevkiyat modelleri
  screens/     Kimlik doğrulama, ana sayfalar, harita ve yapay zekâ ekranları
  services/    Firebase, konum, lojistik, yapay zekâ ve güvenlik servisleri
  widgets/     Paylaşılan bileşenler ve acil durum/SOS arayüzleri
assets/        Uygulama varlıkları (SOS sireni dahil)
test/          Birim ve widget testleri
```

Yerel geliştirme ve anahtar yapılandırması hakkında ek bilgi için
[`DEVELOPMENT.md`](DEVELOPMENT.md) dosyasına bakın.

---