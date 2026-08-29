# Launch — iOS app

A native SwiftUI app for [launch.credit](https://launch.credit), built on the
same design tokens as the marketing site. It opens on the login screen; nothing
else is reachable until a member signs in.

```
open ios/LaunchCredit.xcodeproj      # Xcode 16 or later
```

Pick the **Launch** scheme and run. No dependencies, no package resolution, no
signing team required for the simulator. Deployment target is iOS 17.

---

## What's in it

| Screen | What it does | Comes from the site |
| --- | --- | --- |
| **Login** | Email + password, Face ID / Touch ID unlock, sign-up | first screen, always |
| **Sign up** | Name, email, password, consent — step one of web checkout | `checkout.html` |
| **Home** | Score dial, 12-month trend, this week's one move, hero stat tiles, three-bureau panel | hero + "Inside the app" |
| **Plan** | The diagnosis: every issue ranked by what it costs, with the one move that fixes each | "Ranked by what it costs you" |
| **Build** | Builder account (Basic / Premium / Ultimate) and rent + bill reporting with backdating | "Build history, not debt" |
| **Coach** | The AI coach — chat grounded in the member's real file | "AI coach, 24/7" |
| **You** | Plan and billing, settings, disclosures, sign out, delete account | pricing card + legal |
| **Simulator** | What-if projection — test a move before making it | free score check |
| **Marketplace** | Offers that unlock at the right score, with commission disclosed | "Offers picked for you" |

## Architecture

```
LaunchCredit/
  App/          entry point, auth gate, tab bar
  Theme/        design tokens + shared components (Brand, BrandFont, Card, Chip…)
  Models/       data types, AppState (the single store), seed data
  Services/     auth, keychain, coach engine, score simulator
  Features/     one folder per screen
  Resources/    asset catalog, optional fonts
```

`AppState` is the only store. Views never touch persistence directly, so
swapping the seed data for API responses is a change in one layer.

### Theme

`Theme/Theme.swift` mirrors the CSS custom properties in `index.html` one for
one — the same blues, the same `--grad`, the same hairline borders and card
radii. **If you change a colour on the site, change it here too.**

### Fonts

The site uses Outfit, Plus Jakarta Sans and Instrument Serif. Those files are
not committed (check their licences before shipping). Without them the app
falls back to matching system faces and looks right out of the box. To use the
real thing:

1. Drop the `.ttf` files into `LaunchCredit/Resources/Fonts/`.
2. List each filename under `UIAppFonts` in `LaunchCredit-Info.plist`.

`BrandFont` picks them up automatically — no code change.

## The AI coach

`Services/CoachEngine.swift` has two implementations behind one protocol:

- **`OnDeviceCoach`** — classifies intent and answers from the member's real
  numbers: balances, utilization, reported bills, builder account, next move,
  billing dates. Deterministic, private, and works with no network, which is
  what makes "ask me at 2am" true.
- **`RemoteCoach`** — posts to your backend and **falls back to the on-device
  coach** on any failure, so a member always gets an answer.

To route through a backend, set `LAUNCH_COACH_URL` in `LaunchCredit-Info.plist`
(https only) and store the bearer token in the keychain under `coach.token`.
No key is ever compiled into the binary. Expected contract:

```jsonc
// POST → { "message": "...", "score": 648, "utilization": 0.28,
//          "onTimeStreakMonths": 6, "openFixes": ["..."] }
// 200 ← { "reply": "...", "suggestions": ["..."] }
```

## Accounts and data

- Passwords are **never stored** — only a salted, 50k-round SHA-256 digest in
  the keychain, compared in constant time.
- The session flag lives in `UserDefaults`; everything sensitive is keychain.
- Member data is cached locally and wiped by "Delete account".

`LocalAuthService` is a device-local stand-in so the app runs end to end today.
Point `AuthServicing` at the Launch API and no view changes.

## Before shipping

- [ ] Replace `LocalAuthService` and the seed data with real API calls
- [ ] Set `DEVELOPMENT_TEAM` and a real `PRODUCT_BUNDLE_IDENTIFIER`
- [ ] Add the brand fonts (and confirm their licences)
- [ ] Wire the payment method and cancellation flows in **You**
- [ ] Have compliance review the disclosure copy — it repeats the site's
      "credit-building, not credit repair" language and should stay in sync
