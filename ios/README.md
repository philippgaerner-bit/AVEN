# AVEN iOS — Xcode Setup Guide

## Requirements
- **macOS 14 Sonoma** or later
- **Xcode 15.2** or later (download from Mac App Store or developer.apple.com)
- **iOS 17.0** deployment target
- No SPM dependencies — pure SwiftUI, no third-party packages yet

---

## Open the project

```bash
# From the repository root
open ios/AVEN/AVEN.xcodeproj
```

Or in Xcode: **File → Open** → navigate to `ios/AVEN/AVEN.xcodeproj`

---

## Run on simulator

1. In the Xcode toolbar, select a simulator (e.g. **iPhone 15 Pro**)
2. Press **⌘R** or click the **▶ Run** button
3. The app launches in DEBUG mode using **mock data** (no backend required)

Expected: The full Homescreen appears with sample TikTok profile, score 68/100, and three growth actions.

---

## Run on a physical device

1. Connect your iPhone via USB
2. In **Signing & Capabilities**, set your Apple ID team
3. Change `PRODUCT_BUNDLE_IDENTIFIER` to something unique (e.g. `com.yourname.aven`)
4. Select your device and press **⌘R**

---

## Navigate all tabs

| Tab | Status |
|-----|--------|
| 🏠 Home | **Full implementation** — score, metrics, next steps |
| 📊 Analytics | Polished placeholder — charts Phase 7.2 |
| ➕ (centre) | Opens New Scan sheet |
| ✅ Aktionsplan | Polished placeholder with mock actions |
| 👤 Profil | Polished placeholder with upgrade prompt |

---

## SwiftUI Previews

Each view file includes a `#Preview` block. Open any `.swift` file and click the **Preview** button (canvas icon) to see the design without running the app.

Best files for previews:
- `Features/Home/HomeView.swift` — full Homescreen
- `Features/ActionPlan/ActionPlanView.swift` — action cards
- `Features/NewScan/NewScanSheet.swift` — scan sheet

---

## API environment switching

`Core/Network/APIEnvironment.swift` controls which backend is used:

| Build config | Client |
|---|---|
| `DEBUG` | `StubAVENAPIClient` (mock data, no network) |
| `STAGING` | `RealAVENAPIClient` (Phase 7.2+) |
| `Release` | `RealAVENAPIClient` (Phase 7.2+) |

To test against the local backend (Phase 7.2):
1. Start the backend: `cd packages/backend && node dist/server.js`
2. Set `DEBUG` env var `API_BASE_URL=http://localhost:3000`
3. `RealAVENAPIClient` will be implemented in Phase 7.2

---

## Project structure

```
ios/AVEN/
├── AVEN.xcodeproj/          ← Xcode project (open this)
└── AVEN/
    ├── App/
    │   ├── AVENApp.swift    ← @main entry point
    │   └── AppContainer.swift  ← Dependency injection root
    ├── Core/
    │   ├── DesignSystem/    ← Tokens, colours, components
    │   ├── Models/          ← Domain models (platform-neutral)
    │   └── Network/         ← API client protocol + stub
    ├── Features/
    │   ├── Home/            ← Full implementation
    │   ├── Analytics/       ← Placeholder
    │   ├── ActionPlan/      ← Placeholder
    │   ├── Profile/         ← Placeholder
    │   └── NewScan/         ← Sheet placeholder
    ├── Navigation/
    │   └── RootView.swift   ← Tab bar + sheet wiring
    └── Assets.xcassets/     ← App icon (placeholder) + accent colour
```

---

## What is NOT yet implemented (Phase 7.2+)

- Real HTTP client / URLSession networking
- Keychain token storage
- Apple Sign-In / TikTok OAuth
- StoreKit / RevenueCat
- Screenshot upload flow (PhotosPicker → multipart upload)
- App icon artwork
- Push notification entitlement

---

## Troubleshooting

**Build error: "Cannot find type 'AVENColor'"**  
→ Make sure all files in `Core/DesignSystem/` are in the target. In Xcode: select the file → File Inspector → check "Target Membership: AVEN"

**Simulator shows black screen**  
→ Ensure `preferredColorScheme(.dark)` is set in `AVENApp.swift` (it is)

**Preview not loading**  
→ `Product → Clean Build Folder` (⌘⇧K), then reopen the canvas
