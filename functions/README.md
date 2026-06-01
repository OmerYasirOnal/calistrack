# CalisTrack Cloud Functions

`generateProgram` — a callable that turns a generation request
(`{level, goals, daysPerWeek, equipment}`) into a strict-JSON `Program` via
OpenAI. The OpenAI key lives only as a Firebase secret; the client never sees it
and it is never committed.

## Deploy (one-time owner setup)

Requires a Firebase project wired to the app (`flutterfire configure`) and an
OpenAI API key.

```bash
cd functions
npm install
firebase functions:secrets:set OPENAI_API_KEY   # paste the key when prompted
firebase deploy --only functions
```

The model is `gpt-4o-mini` (change `MODEL` in `src/index.ts` if desired). The
function validates/sanitizes the model output server-side and only allows
`exerciseId`s from the bundled library.

## Until it's deployed

The Flutter client is **fallback-first**: `AiProgramService` falls back to a
deterministic local template when the function is absent or errors, so the
"Generate" flow always produces a usable program. Deploying this function simply
upgrades that to real OpenAI-tailored output.
