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
| **Plan** | Your goal, then the diagnosis: every issue ranked by what it costs, each opening to the one move that fixes it | "Ranked by what it costs you" |
| **Build** | The builder account, and rent / phone / power / internet switched on to report | "Build history, not debt" |
| **Coach** | The AI coach, grounded in the member's real file | "AI coach, 24/7" |
| **Account** | Plan and billing, what's included, disclosures, sign out — behind the avatar on Home | pricing card + footer legal |
| **Simulator** | What-if projection — test a move before making it | "What-if simulator" |
| **Your goal** | Pick the thing you're financing; get the score, the steps, the date and what waiting costs | "your step-by-step plan" |
| **Card matches** | Cards matched to the file with the reason each was picked | "offers picked for you" |

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

Utilization is **derived, never stored** — `ScoreSimulator.utilization(of:)`
over the member's cards. Marking this week's move done debits the card it
names, which moves utilization, the score and the *next* move together, so the
file never drifts away from the checkbox.

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

- **`OnDeviceCoach`** — reads the question, then does arithmetic on the
  member's real file. Deterministic, private, works with no network, which is
  what makes "ask me at 2am" true.
- **`RemoteCoach`** — posts to your backend and **falls back to the on-device
  coach** on any failure, so a member always gets an answer.

It does five things:

1. **Payment reminders.** `ReminderService` derives the dates from the file —
   statement dates (not due dates; whatever the balance is when it *closes* is
   what reports), the builder payment, stalled bill verifications — and
   schedules local notifications a few days ahead.
2. **Tells them what's hurting.** A ranked diagnosis with the point cost and
   the annual dollar cost of each issue, worst first.
3. **Simulates the fixes.** "What will my score be after?" runs the whole open
   list through `ScoreSimulator` and gives the number, the band, and an honest
   timeline.
4. **Goals.** "I want to finance a $30k car" → the score good terms need, the
   APR at today's score versus that score, the monthly payment difference, the
   lifetime cost of waiting, and the ordered steps to close the gap.
   `GoalEngine` holds the rate bands and the amortisation.
5. **Card recommendations.** `CardAdvisor` matches on score, file thickness and
   what's being carried — a balance-transfer card when a card is strained, a
   secured card under 620 — each with the reason, and commission disclosed.

What makes the on-device coach worth having:

- **It computes, it doesn't recite.** "How much should I pay?" returns the
  actual figure that clears 30% on the actual card, by the actual statement
  date, with the point estimate that figure is worth. "What if I pay $300?"
  answers the amount they named, and says what the right number would be.
- **It carries the thread.** `CoachQuery` pulls dollar figures and target
  scores out of the sentence; `CoachIntent.classify` weighs phrases above
  words, and a bare follow-up ("how much?", "why?") inherits the last topic.
- **It can act.** A reply may carry a `CoachAction` — mark the move done,
  switch a bill on, track a goal, show card matches, turn reminders on —
  rendered as one button under the answer, so the member never goes hunting
  for the screen.
- **It shares one model with the rest of the app.** Every point estimate,
  in chat, on Home and in the simulator, comes from `ScoreSimulator`, so the
  three can't quietly disagree.

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
- [ ] Have compliance review the disclosure copy and the coach's answers —
      both repeat the site's "credit-building, not credit repair" language
      and should stay in sync
