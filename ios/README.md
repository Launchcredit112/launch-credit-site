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

Four tabs, because the site promises four things. Nothing in the app exists
that the site does not already sell.

| Screen | What it does | On the site as |
| --- | --- | --- |
| **Sign in** | Email + password. Accounts are created in the web checkout. | first screen, always |
| **Home** | Score, 12-month trend and the three numbers behind it; this week's one move; all three bureaus | hero + "Inside the app" |
| **Plan** | The diagnosis: every issue ranked by what it costs, each opening to the one move that fixes it | "Ranked by what it costs you" |
| **Build** | The builder account, and rent / phone / power / internet switched on to report | "Build history, not debt" |
| **Coach** | The AI coach, grounded in the member's real file | "AI coach, 24/7" |
| **Account** | Plan and billing, what's included, disclosures, sign out — behind the avatar on Home | pricing card + footer legal |
| **Simulator** | What-if projection — test a move before making it | "What-if simulator" |

Deliberately **not** built: biometric unlock, in-app sign-up (the checkout
collects SSN and address — that stays on the web), free-form bill entry,
changing the builder tier after checkout, and account deletion. The
marketplace the site runs is not in the app either — the coach still answers
whether a file is ready for an application, it just doesn't sell against it.

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

The app only ever signs in — accounts are created in the web checkout, which
collects the identity and consents the credit partner needs.

- Passwords are **never stored** — only a salted, 50k-round SHA-256 digest in
  the keychain, compared in constant time.
- The session flag lives in `UserDefaults`; everything sensitive is keychain.

`LocalAuthService` is a device-local stand-in for that API, so the app runs end
to end today: **the first sign-in on a device provisions the member** from the
email you give it (any valid address, any password of 8+ characters including a
number), and every sign-in after that is checked against it. Point
`AuthServicing` at the real endpoint and no view changes.

## Before shipping

- [ ] Replace `LocalAuthService` and the seed data with real API calls
- [ ] Set `DEVELOPMENT_TEAM` and a real `PRODUCT_BUNDLE_IDENTIFIER`
- [ ] Add the brand fonts (and confirm their licences)
- [ ] Point the sign-up link at the live checkout URL if it ever moves
- [ ] Have compliance review the disclosure copy — it repeats the site's
      "credit-building, not credit repair" language and should stay in sync
