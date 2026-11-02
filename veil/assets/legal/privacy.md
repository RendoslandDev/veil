# Privacy Policy

Version 2026-10-29 · Effective [EFFECTIVE DATE]

Veil is built around one promise: **you are only findable if you say yes.** This policy explains what Veil handles, where it lives, and what you control. It describes the app as it works today.

## The short version

- **Everything stays on your phone.** This version of Veil has no accounts, no servers and no internet connection. We, the makers of Veil, never receive your photos, your face data, your messages or your name.
- **Your face is only searchable with your signed consent**, and that consent always expires.
- **Nobody learns who you are from a search.** A match only creates a request. You decide whether to reveal yourself.
- **You can delete your face data at any time**, and it is deleted automatically when your consent expires.
- **No ads, no analytics, no tracking, no selling of data.**

## Who we are

Veil is provided by [COMPANY LEGAL NAME], [ADDRESS] ("we", "us"). Contact us about privacy at [PRIVACY EMAIL].

## What Veil handles

### Your display name

The name you type when you first open the app. It is stored on your phone and shown to a person only when you send them a request or when you approve theirs.

### Photos

When you enroll or search, you take or choose a photo. Veil:

- analyzes it **on your phone** using Apple's built-in Vision framework and an on-device model,
- checks its quality (one face, facing forward, sharp, well lit),
- turns the face into a face template (see below), and
- **deletes the temporary copy of the photo** as soon as processing finishes.

Veil never uploads, keeps or shares the photo itself. Photos you choose from your library stay in your library; Veil only gets access to the photos you pick.

### Face templates (biometric data)

A face template is a list of numbers that describes the geometry of a face. It is **biometric data**, which many laws treat as sensitive. Veil creates a template:

- **When you enroll** ("Become findable"): your template is stored on your phone together with your signed consent, so that searches can match you.
- **When you search**: a template is made from the search photo, compared once, and then **discarded**. It is never stored.

A template cannot be turned back into your photo by Veil, but we treat it with the same care as the photo.

### Liveness check

Before enrolling, Veil asks you to blink, nod and turn your head in front of the camera. The camera frames are analyzed on your phone in real time and are not saved. Only the final still photo is used to make your template, then deleted.

### Consent records and signing key

When you enroll, Veil creates a consent record (who consented, to what, when it was issued and when it expires, and which version of this policy you agreed to). Your phone signs it with a private key that is stored in the iOS Keychain and never leaves your device.

### Requests, notes and messages

When someone's search matches you, a request is created with their name, an optional note, the time and a similarity score. If you approve it, a chat opens. Requests, notes and messages are stored on your phone.

### Search history

Veil keeps the time of each search for 24 hours so it can enforce the daily search limit. It does not keep the search photo or template.

## Why Veil uses this data

Only to provide the features you ask for:

- to let people who already know you find you, **only if you consented**,
- to tell you who is asking, so you can approve, deny or block,
- to let you chat after you approve,
- to prevent abuse (requiring searchers to be enrolled, and limiting searches).

Our legal bases, where the law requires one, are your **explicit consent** (for face templates and the liveness check) and our legitimate interest in keeping the app safe (for the search limit).

We do not use your data for advertising, profiling, training AI models, or anything else.

## Who can see it

- **Us: nobody.** This version of Veil sends nothing to us or to anyone else.
- **Other people:** only what you choose to reveal. Someone who searches never sees your name, your template or whether anyone matched. They learn your name only if you approve their request.
- **Apple:** Veil uses Apple's on-device Vision framework, which runs on your phone. If you back up your phone to iCloud, Veil's files may be included in that backup under Apple's terms.
- **Authorities:** we hold no data about you, so there is nothing for us to disclose.

We do not sell or rent personal data, and we do not share it for advertising.

## How long it is kept

| Data | Kept until |
|---|---|
| Photos (temporary copy) | Deleted as soon as processing finishes |
| Search templates | Discarded right after comparison |
| Your face template | You revoke consent, or your consent expires (30, 90 or 365 days, your choice), whichever comes first |
| Consent record | Deleted together with your template |
| Search times | 24 hours, or until you delete your face data |
| Name, requests, notes, messages | Until you delete the app |
| Signing key | Stored in the iOS Keychain; iOS may keep Keychain items after you delete the app. It is not biometric data and is replaced if you reinstall |

**We will permanently destroy face templates when the purpose for which they were collected has been satisfied, or within 3 years of your last interaction with Veil, whichever comes first.** In practice this is much sooner, because consent can last at most 365 days.

## Your choices and rights

- **Withdraw consent:** Privacy tab → "Revoke and delete face data". Your template and consent record are deleted immediately and searches can no longer match you.
- **Renew or shorten consent:** re-enroll and choose a new period.
- **Deny or block:** decline any request. Blocking stops that person's searches from reaching you, and they only see "declined".
- **Delete everything:** delete the app. iOS removes all of Veil's data from your phone (except the signing key noted above).
- **Access and portability:** all of your data is on your own phone.

Depending on where you live, laws such as Ghana's Data Protection Act, 2012 (Act 843), the EU and UK GDPR, the Illinois Biometric Information Privacy Act, and US state privacy laws give you further rights, including to access, correct, delete and object. Because we hold no copy of your data, the controls above are how you exercise them. You can also contact us at [PRIVACY EMAIL] or complain to your local data protection authority (in Ghana, the Data Protection Commission).

## Security

Your data never leaves your phone, so it is protected by your phone's own security: your passcode, Face ID or Touch ID, and iOS data protection. The signing key is kept in the iOS Keychain. Please use a passcode on your phone: anyone who can unlock it can open Veil.

## Children

Veil is for people **18 and over**. Do not enroll a child, and do not search using a photo of a child. If you believe a child has enrolled, delete their face data in the app.

## Changes to Veil and to this policy

If Veil ever starts sending any data off your phone (for example, to let people on different phones find each other), **we will update this policy and ask for your consent again before any data leaves your device.** For other material changes we will show a notice in the app. The version and date at the top tell you which policy you are reading, and your consent record stores the version you agreed to.

## Contact

[COMPANY LEGAL NAME]
[ADDRESS]
[PRIVACY EMAIL]
