# CalisTrack — Store listing & ASO pack (EN + TR)

**Date:** 2026-06-03 · Companion to the
[strategy brief](2026-06-03-monetization-strategy-brief.md) (§6 market & positioning).
Copy is ready to paste into App Store Connect / Play Console. Character budgets
noted; **Apple indexes screenshot caption text (since Jun 2025)** — use the
captions below. Turkish is the launch beachhead (low ASO competition).

> Owner: verify keyword volumes/difficulty against your ASO tool at submission
> (the brief targets difficulty < 50, popularity ~20–50). Don't keyword-stuff the
> description — Apple ranks the keyword field, Google ranks the description.

---

## Positioning (1 line)

- **EN:** The skill-progression tracker for calisthenics — log workouts and unlock the muscle-up, front lever, planche & handstand.
- **TR:** Kalisteni için beceri-ilerleme takipçisi — antrenmanını kaydet; muscle-up, front lever, planche ve amuda doğru ilerle.

---

## App name & subtitle

**Apple** — name ≤ 30 chars, subtitle ≤ 30 chars:
- Name (EN): `CalisTrack: Calisthenics` (24)
- Subtitle (EN): `Skill tracker & AI plans` (24)
- Name (TR): `CalisTrack: Kalisteni` (21)
- Subtitle (TR): `Beceri takibi & AI program` (26)

**Google Play** — title ≤ 30, short description ≤ 80:
- Title (EN): `CalisTrack — Calisthenics` (25)
- Short desc (EN): `Track bodyweight workouts, unlock skills like the muscle-up & front lever.` (74)
- Title (TR): `CalisTrack — Kalisteni` (22)
- Short desc (TR): `Vücut ağırlığı antrenmanı takip et; muscle-up ve front lever'a ilerle.` (70)

---

## Apple keyword field (≤ 100 chars, comma-separated, no spaces, no plurals/repeats of the name)

- **EN:** `calisthenics,bodyweight,muscle up,front lever,planche,handstand,pull up,push up,workout tracker,skill` (100)
- **TR:** `kalisteni,kalistenik,vücut ağırlığı,barfiks,şınav,amuda kalkış,muscle up,front lever,antrenman,takip` (~99)

Head terms to **avoid** as primary (too competitive): `fitness`, `gym`, `workout`
(alone). Win the niche modifiers instead.

---

## Full description

### EN

> **Build real calisthenics strength — and finally unlock the skills.**
>
> CalisTrack is the bodyweight-training tracker built around skill progression.
> Log your push, pull, legs and core sessions, watch your reps and volume climb,
> and follow step-by-step trees toward the moves everyone wants: the muscle-up,
> front lever, planche and handstand.
>
> • **Smart next target** — on-device guidance suggests your next set (progress,
>   hold, or back off) from your own history. Free, private, works offline.
> • **Skill trees** — clear, staged paths from your first tuck to the full hold.
> • **Progress charts** — reps, weight and volume per exercise over time.
> • **AI program generation** (Pro) — a plan tailored to your level, goals, days
>   and equipment.
> • **Offline-first** — log anywhere; your data syncs when you're back online.
>
> Free to use. Upgrade to **Pro** for AI programs, the full skill trees, advanced
> analytics, and an ad-free experience.

### TR

> **Gerçek kalisteni gücü kazan — ve o becerileri sonunda aç.**
>
> CalisTrack, beceri ilerlemesi etrafında kurulmuş bir vücut-ağırlığı antrenman
> takipçisidir. Push / pull / bacak / core seanslarını kaydet, tekrar ve hacmini
> yüksel; herkesin istediği hareketlere adım adım ilerle: muscle-up, front lever,
> planche ve amuda kalkış.
>
> • **Akıllı Sonraki Hedef** — cihaz-içi rehberlik, kendi geçmişinden sonraki
>   setini önerir (ilerle, koru veya geri çekil). Ücretsiz, gizli, çevrimdışı.
> • **Beceri ağaçları** — ilk tuck'tan tam tutuşa net, kademeli yollar.
> • **İlerleme grafikleri** — egzersiz başına tekrar, ağırlık ve hacim.
> • **AI program üretimi** (Pro) — seviyene, hedefine, günlerine ve ekipmanına
>   göre kişisel program.
> • **Önce çevrimdışı** — her yerde kaydet; çevrimiçi olunca senkronize olur.
>
> Kullanımı ücretsiz. **Pro** ile AI programlar, tam beceri ağaçları, gelişmiş
> analiz ve reklamsız deneyim.

---

## Screenshot captions (Apple indexes these — keyword-rich, ≤ ~6 words each)

| # | EN | TR |
|---|---|---|
| 1 | Track every calisthenics workout | Her kalisteni antrenmanını takip et |
| 2 | Smart next-set targets, on-device | Akıllı sonraki-set hedefi, cihazda |
| 3 | Unlock the muscle-up & front lever | Muscle-up ve front lever'ı aç |
| 4 | Planche & handstand skill trees | Planche ve amuda beceri ağaçları |
| 5 | Progress charts: reps & volume | İlerleme grafikleri: tekrar & hacim |
| 6 | AI programs tailored to you (Pro) | Sana özel AI programlar (Pro) |

---

## Category, age & data safety

- **Category:** Health & Fitness.
- **Age rating:** 4+ / Everyone.
- **Data safety / App Privacy (declare):** account email; profile (level, goals,
  height/weight); workout history → Firebase Auth + Firestore. Advertising ID
  (IDFA/GAID) via AdMob for free-tier ads. Google Sign-In. The on-device model
  uses no data off-device. Link the hosted privacy policy
  ([`docs/privacy-policy.md`](../privacy-policy.md)).

## "What's new" (first release)

- **EN:** First release — log calisthenics workouts, follow skill trees toward the
  muscle-up, front lever, planche & handstand, and get on-device smart targets.
- **TR:** İlk sürüm — kalisteni antrenmanlarını kaydet; muscle-up, front lever,
  planche ve amuda doğru beceri ağaçlarını takip et; cihaz-içi akıllı hedefler al.

## Go-to-market notes (from brief §6)

- **TR beachhead first:** rank #1 cheaply on `kalisteni`, harvest reviews + Day-7
  retention (a ranking factor), then compound into the English market.
- **Organic channels ($0):** r/bodyweightfitness + calisthenics Discords — offer
  the free tracker for the community's Recommended Routine (contribute, don't spam).
- **Custom Product Pages:** one per skill (muscle-up / front lever) for targeted links.
