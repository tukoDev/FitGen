# FitGen

AI destekli kişisel fitness koçu. SwiftUI ile geliştirilmiş iOS uygulaması.

## Özellikler

### Kişiselleştirilmiş Antrenman Programı
- Onboarding sırasında girilen yaş, kilo, boy, hedef ve aktivite seviyesine göre Groq AI tarafından 6 günlük haftalık program oluşturulur
- Her egzersiz için set, tekrar, hedef kas grubu ve adım adım talimatlar içerir

### Gerçek Zamanlı Form Analizi
- Kamera ve Apple Vision framework kullanarak egzersiz sırasında vücut pozu algılanır
- 19 eklem noktası iskelet olarak ekran üzerine çizilir
- Anlık geri bildirim ile form hataları tespit edilir
- Ön/arka kamera desteği ve yön değişikliği ile uyumlu çalışır

### AI Koç
- Groq API (Llama 3.3 70B) ile sohbet tabanlı fitness danışmanı
- Antrenman, beslenme ve hedefler hakkında kişiselleştirilmiş yanıtlar

### Profil
- Kullanıcı bilgileri ve hedefleri AppStorage ile kalıcı olarak saklanır

## Ekran Görüntüleri

| Onboarding | Program | Form Analizi |
|---|---|---|
| Kişisel bilgi girişi | AI destekli haftalık plan | Gerçek zamanlı iskelet tespiti |

## Kurulum

1. Repoyu klonlayın:
   ```bash
   git clone https://github.com/tukoDev/FitGen.git
   cd FitGen
   ```

2. API anahtarlarını ayarlayın:
   ```bash
   cp FitGen/Constants.example.swift FitGen/Constants.swift
   ```
   `Constants.swift` dosyasını açın ve kendi API anahtarlarınızı girin:
   ```swift
   enum Constants {
       static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
       static let groqAPIKey   = "YOUR_GROQ_API_KEY"
   }
   ```

3. `FitGen.xcodeproj` dosyasını Xcode ile açın ve çalıştırın.

## API Anahtarları

| Servis | Nereden alınır |
|---|---|
| Groq | [console.groq.com](https://console.groq.com) |
| Gemini | [aistudio.google.com](https://aistudio.google.com) |

## Teknolojiler

- **SwiftUI** — Arayüz
- **AVFoundation** — Kamera erişimi
- **Vision** — Vücut pozu tespiti (`VNDetectHumanBodyPoseRequest`)
- **Groq API** — Llama 3.3 70B model ile program oluşturma ve sohbet
- **AppStorage** — Kullanıcı verilerinin kalıcı depolanması

## Gereksinimler

- iOS 17+
- Xcode 15+
- Gerçek cihaz (Form Checker için kamera gereklidir)
