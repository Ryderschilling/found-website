# FOUND — App Preview Video Storyboard
**Duration:** 15 seconds
**Format:** 886 × 1920 px (9:19.5, vertical) or 1080 × 1920 px
**Spec:** Apple App Store App Preview — MP4 / H.264, 30fps

---

## Frame-by-Frame Breakdown

---

### Frame 01 — 0:00–0:01.5 (1.5s)
**Scene:** Splash / Logo Intro
**Visual:** Black screen. The FOUND logo ("F." ring) fades in center screen with a subtle golden glow pulse radiating outward. The word "FOUND" appears below in white.
**Motion:** Fade in + scale from 0.9→1.0 with ease-out.
**Text on screen:** `F.` (logo) + `FOUND` underneath
**Audio cue:** Soft, warm ambient tone — single piano note or choir pad.

---

### Frame 02 — 0:01.5–0:03 (1.5s)
**Scene:** Onboarding — Intent selection
**Visual:** Onboarding screen ("What brings you to FOUND?") slides up from bottom. Four option cards visible. One taps/highlights in gold ("Find Christian friends nearby") with a subtle press animation.
**Motion:** Slide up from bottom (spring), then tap animation on the first option card (scale 0.97→1.0).
**Text on screen:** `"What brings you to FOUND?"`
**Tagline overlay (top):** *(none — let the UI speak)*

---

### Frame 03 — 0:03–0:05 (2s)
**Scene:** Discover — Browsing people
**Visual:** Discover screen appears. The list of profile cards is visible. Camera-style subtle pan/scroll reveals 3 cards. Each card animates in with a staggered entrance (card 1, then card 2, then card 3 with 100ms delay each).
**Motion:** Scroll down 200px at natural pace.
**Text on screen:** `Discover` header, filter chips, 3 profile cards
**Tagline overlay (bottom, in gold):** `"Find your people."`

---

### Frame 04 — 0:05–0:07 (2s)
**Scene:** Profile Detail — Tapping a card
**Visual:** Tap on Jake M.'s card → profile detail view slides in from the right. The 3×3 photo grid loads, interest tags appear, the "Connect" and "Wave" buttons slide up from bottom.
**Motion:** Push transition right-to-left (standard iOS nav). Tags stagger in with 80ms delay each.
**Text on screen:** Full profile: name, city, interests, In Common section
**Tagline overlay (bottom, in gold):** `"More than just a photo."`

---

### Frame 05 — 0:07–0:09 (2s)
**Scene:** Connect tap → Match moment
**Visual:** Finger taps the gold "Connect" button. Button pulses gold. Screen transitions to the match overlay — "It's a Match!" — with the two profile circles and the gold cross icon in the center. A burst of soft golden particles emanates from the center.
**Motion:** Button tap pulse → crossfade to match screen → particle burst (subtle, not cheesy). Two profile circles slide in from left and right.
**Text on screen:** `"It's a Match!"` + `"You and Jake both wanted to connect."`
**Tagline overlay:** *(none — let the moment breathe)*

---

### Frame 06 — 0:09–0:10.5 (1.5s)
**Scene:** Send Message CTA
**Visual:** Zoom in slightly on the sage green "Send a Message" button. Button glows lightly. Tap animation → chat screen slides in.
**Motion:** Subtle zoom (1.0→1.03) on button, then tap → slide right.
**Text on screen:** Match modal with both CTAs visible

---

### Frame 07 — 0:10.5–0:12.5 (2s)
**Scene:** Messaging — Conversation in progress
**Visual:** Chat thread scrolls naturally, showing the 3-message exchange. Message bubbles appear one by one as if being typed (typing indicator → bubble appears). Gold outgoing bubble visible at bottom.
**Motion:** Scroll from top of conversation to bottom, bubbles fade/scale in (0.85→1.0).
**Text on screen:** Full chat thread — Bayside / young adults / hiking messages
**Tagline overlay (bottom, in gold):** `"Real conversations."`

---

### Frame 08 — 0:12.5–0:14 (1.5s)
**Scene:** Groups tab
**Visual:** Tab bar taps to Groups. Groups screen appears — 3 group cards visible. "Bayside Young Adults" card is highlighted (subtle gold border pulse since it's already Joined).
**Motion:** Tab tap animation → screen cross-dissolve. Group cards stagger in (100ms apart).
**Text on screen:** Groups header, 3 group cards
**Tagline overlay (bottom, in gold):** `"Find your church community."`

---

### Frame 09 — 0:14–0:15 (1s)
**Scene:** End card / Logo lockup
**Visual:** Fade to black. FOUND logo re-appears in center with gold glow. Tagline appears below in white. App Store badge (or CTA text) fades in at the bottom.
**Motion:** Fade to black from groups screen. Logo fades in. Text appears with 0.5s delay.
**Text on screen:**
  `F.`
  `FOUND`
  `Find your people. Right where you are.`
  `Available on the App Store` *(optional)*

---

## Transition Guide

| Between | Transition |
|---|---|
| Frame 1 → 2 | Fade |
| Frame 2 → 3 | Slide up (sheet) |
| Frame 3 → 4 | Push right (iOS nav) |
| Frame 4 → 5 | Crossfade → particle burst |
| Frame 5 → 6 | Zoom in on button |
| Frame 6 → 7 | Push right (iOS nav) |
| Frame 7 → 8 | Tab crossfade |
| Frame 8 → 9 | Fade to black |

---

## Production Notes

- **No voiceover** — music only. Suggest: ambient gospel/worship-influenced instrumental. Something warm and modern, not cheesy.
- **Text overlays** should use white (#FFFFFF) in a bold sans-serif (SF Pro Display or Inter) at ~52px for the 886px wide canvas.
- **Gold accent** (#C9A84C) for any highlighted text overlays or animated underlines.
- All animations should feel **native iOS** — use spring physics (stiffness ~300, damping ~30) not linear/ease curves.
- **Safe zone**: Keep all UI content within 80px margin on all sides.
- **No talking/face-to-camera** — Apple requires this stays focused on the app UI.
- Tool recommendation: **ScreenFlow**, **Final Cut Pro**, or **After Effects** for assembly. Record real device interactions on iPhone 15 Pro in the simulator or on device, then composite.

---

## Quick Spec Summary

| Property | Value |
|---|---|
| Duration | 15 seconds |
| Resolution | 886 × 1920 px |
| Frame rate | 30 fps |
| Format | H.264 MP4 |
| Audio | AAC, optional |
| Required for | iPhone App Store listing |
