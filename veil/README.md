# Veil

Consent-first face identity. You are only findable if you say yes, and nobody learns who you are unless you approve them.

## How each flaw is handled

| Flaw | Fix in Veil | Where enforced | Status |
|---|---|---|---|
| Stalking from a secret photo | Only people with active, signed, expiring consent can be matched. A search never returns an identity, only a request the matched person approves. | Postgres (`search_face`, RLS) | Phase 1 ✅ |
| Probing "is this face in the system?" | `search_face` returns the same response whether or not anyone matched | Postgres | Phase 1 ✅ |
| Anonymous abuse | Searchers must be enrolled themselves; 10 searches a day; requester's name shown to the target; block | Postgres | Phase 1 ✅ |
| Scraping without consent | Nothing is scraped. Templates exist only for users who enrolled | Design | Phase 1 ✅ |
| Biometric breach | Photos never leave the device; only a 192-float template is stored, readable by its owner only; revoking hard-deletes it | Device + RLS | Phase 1 ✅ (template still sits on the server; see limits) |
| False positives / lookalikes | Quality gate (one face, frontal, size, lighting) + strict 0.80 threshold + **human approval** before anything is revealed | Device + Postgres + user | Phase 1 ✅ |
| Low-quality images | Rejected with a specific reason instead of producing a bad match | Device | Phase 1 ✅ |
| Demographic bias | A bias-driven false match still can't reveal anyone, because the target must approve. Model choice and per-group threshold audit come next | User approval | Partial |
| Spoofing enrollment with a photo | Randomized blink / nod / head-turn liveness (Apple Vision, on device) | Device | Partial (client-reported; see limits) |
| PimEyes and similar tools | Can't be controlled from our app | — | Phase 2: photo cloaking + removal-request generator |

## Known limits

- **Liveness is reported by the client.** A modified app could lie. The fix is server-attested liveness (App Attest / Play Integrity, or a liveness vendor).
- **Templates live on the server**, because matching across users needs them there. They are never readable by other users, but a database breach would expose them.
- **Consent signatures are stored, not yet verified on the server.** An Edge Function should verify the Ed25519 signature before accepting a template.

## Running (local mode, no accounts)

Right now Veil runs entirely on the phone: no login, no server. Data lives in one JSON file in the app's support folder, and `lib/services/repo.dart` enforces the same rules as `supabase/migrations/20261029000000_init.sql`, so a backend can replace it later without changing behavior.

```bash
flutter run
```

- **Face matching** uses a bundled MobileFaceNet model at `assets/models/mobilefacenet.tflite` (112x112 input) if present. Otherwise it falls back to Apple Vision's built-in image feature print. That needs no download but isn't a face model, so its 0.90 threshold is uncalibrated; debug builds show the best similarity after each search so it can be tuned.
- **Testing both sides on one device:** debug builds have a person switcher (avatar, top right). Add a test person, enroll each with the DEV photo button, search as one, and approve or deny as the other.
- **Simulator:** no camera, so use the DEV photo button. Add face photos with `xcrun simctl addmedia booted photo.jpg`. Real liveness needs a physical iPhone.
- **Tests:** `flutter test` covers the privacy rules (hidden identity, approval gate, blocking reads as denied, rate limit, revoke).
