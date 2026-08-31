# AVEN KI-Video Setup — Runway ML Gen-3 Alpha Turbo

AVEN nutzt **Runway ML Gen-3 Alpha Turbo** für echte KI-Video-Generierung.
Gen-3 Alpha Turbo erstellt hochwertige 5–10-Sekunden-Clips aus einem Text-Prompt —
realistische Bewegungen, Beleuchtung, Szenen, passend zum Short-Form-Stil.

---

## Schritt-für-Schritt

### 1. Runway ML Account anlegen
- Gehe zu https://app.runwayml.com
- Erstelle einen Account (kostenlose Testversion verfügbar)
- Öffne **Settings → API → Create new API key**
- Kopiere den Key

### 2. Backend konfigurieren
```bash
# In packages/backend/.env oder als Umgebungsvariablen:
RUNWAY_API_KEY=rw_xxxxxxxxxxxxxxxxxxxxxx
RUNWAY_API_URL=https://api.runwayml.com/v1   # optional, das ist der Default
```

### 3. Backend starten
```bash
cd packages/backend
RUNWAY_API_KEY=rw_xxx node dist/server.js
```

### 4. iOS konfigurieren
In Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables:
```
AVEN_API_URL = http://localhost:3000
```

### 5. Testen
1. Öffne AVEN im Simulator
2. „+" → Video-Konzept erstellen
3. Thema eingeben → Stil wählen → „Konzept erstellen"
4. „Video generieren" tippen
5. Runway ML generiert das Video (~30–90 Sek)
6. Videovorschau mit AVPlayer öffnet sich

---

## Preise (Runway ML, Stand 2025)
- Kostenlos: 125 Credits / Monat (ca. 12–25 Videos à 5 Sek)
- Standard ($15/Monat): 625 Credits
- Unlimited ($95/Monat): unbegrenzt

Ein 10-Sek-Video kostet ca. 10 Credits.

---

## Alternative Anbieter
Falls Runway nicht passt:

| Anbieter | API | Qualität | Preis |
|----------|-----|---------|-------|
| **Kling AI** | https://api.klingai.com | Sehr gut | Credits |
| **Pika 2.0** | https://pika.art/api | Gut | Credits |
| **Luma Dream Machine** | https://lumalabs.ai/api | Sehr gut | Credits |

Für einen anderen Anbieter: `packages/backend/src/modules/video/video-routes.ts` anpassen.
Der iOS-Code bleibt unverändert — er spricht nur AVEN-Backend-Endpunkte.

---

## Technische Details
- Runway Modell: `gen3a_turbo`
- Format: 9:16 (768×1280, Hochformat)
- Dauer: 5–10 Sekunden
- Der AVEN-Prompt wird aus Hook + Style + Plattform zusammengesetzt
- Kein Text/Subtitel im Video (Runway unterstützt das noch nicht nativ)
