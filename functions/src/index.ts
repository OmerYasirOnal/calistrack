import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

// The OpenAI key lives ONLY here, as a Firebase secret — never in the client or
// the repo. Set it with:
//   firebase functions:secrets:set OPENAI_API_KEY
const openaiKey = defineSecret("OPENAI_API_KEY");

// Must mirror assets/data/exercises.json. The model may ONLY use these ids.
const EXERCISE_IDS = [
  "push_up", "diamond_push_up", "dip", "pike_push_up", "pseudo_planche_push_up",
  "pull_up", "chin_up", "australian_row", "scapular_pull",
  "pistol_squat", "bulgarian_split_squat", "nordic_curl", "calf_raise",
  "hanging_leg_raise", "plank", "hollow_hold", "l_sit",
  "easy_run", "intervals",
];

const MODEL = "gpt-4o-mini";

function systemPrompt(): string {
  return [
    "You are a calisthenics coach. Produce a training program as STRICT JSON.",
    "Shape: {name, description, days:[{label, exercises:[{exerciseId, targetSets,",
    "and exactly ONE of targetReps | targetHoldSeconds | targetDistanceMeters |",
    "targetDurationSeconds}]}]}.",
    `Use ONLY these exerciseId values: ${EXERCISE_IDS.join(", ")}.`,
    "Reps movements use targetReps; plank/hold/l_sit use targetHoldSeconds;",
    "easy_run uses targetDistanceMeters; intervals uses targetDurationSeconds.",
    "Return ONLY the JSON object, no prose.",
  ].join(" ");
}

/** Coerce a positive integer, or undefined. */
function posInt(v: unknown): number | undefined {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : undefined;
}

/**
 * Keep only movements with a known id and EXACTLY ONE valid numeric target.
 * Exercises carry `exerciseId` + targets only (no `name`) — the client resolves
 * display names from the bundled exercise library, the single source of truth,
 * exactly like `assets/data/programs.json`.
 */
function sanitize(program: any): any {
  const days = Array.isArray(program?.days) ? program.days : [];
  const cleanDays = days
    .map((d: any) => ({
      label: String(d?.label ?? "Day"),
      exercises: (Array.isArray(d?.exercises) ? d.exercises : [])
        .filter((e: any) => EXERCISE_IDS.includes(e?.exerciseId))
        .map((e: any) => {
          const reps = posInt(e.targetReps);
          const hold = posInt(e.targetHoldSeconds);
          const dist = posInt(e.targetDistanceMeters);
          const dur = posInt(e.targetDurationSeconds);
          const present =
            [reps, hold, dist, dur].filter((x) => x !== undefined);
          if (present.length !== 1) return null; // exactly one target required
          return {
            exerciseId: e.exerciseId as string,
            targetSets: posInt(e.targetSets) ?? 3,
            ...(reps !== undefined ? {targetReps: reps} : {}),
            ...(hold !== undefined ? {targetHoldSeconds: hold} : {}),
            ...(dist !== undefined ? {targetDistanceMeters: dist} : {}),
            ...(dur !== undefined ? {targetDurationSeconds: dur} : {}),
          };
        })
        .filter((e: any) => e !== null),
    }))
    .filter((d: any) => d.exercises.length > 0);

  if (cleanDays.length === 0) {
    throw new HttpsError("internal", "Model returned no usable movements.");
  }
  return {
    name: String(program?.name ?? "AI Program"),
    description: String(program?.description ?? ""),
    days: cleanDays,
  };
}

export const generateProgram = onCall(
  {secrets: [openaiKey]},
  async (request) => {
    // Authenticated callers only — this hits the paid OpenAI API, so an open
    // callable would be a cost-abuse vector. (Also enable App Check + per-user
    // rate limiting before a public launch.)
    if (request.auth == null) {
      throw new HttpsError("unauthenticated", "Sign in to generate a program.");
    }

    const {level, goals, daysPerWeek, equipment} = request.data ?? {};
    if (typeof daysPerWeek !== "number" || daysPerWeek < 1 || daysPerWeek > 7) {
      throw new HttpsError("invalid-argument", "daysPerWeek must be 1..7.");
    }

    const userMsg =
      `Level: ${level ?? "beginner"}. Goals: ${
        Array.isArray(goals) ? goals.join(", ") : goals ?? "general"
      }. Days per week: ${daysPerWeek}. Equipment: ${
        Array.isArray(equipment) ? equipment.join(", ") : equipment ?? "bar"
      }.`;

    let res: Response;
    try {
      res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openaiKey.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: MODEL,
          max_tokens: 1200, // cap cost + avoid truncated JSON
          response_format: {type: "json_object"},
          messages: [
            {role: "system", content: systemPrompt()},
            {role: "user", content: userMsg},
          ],
        }),
      });
    } catch (e) {
      // Log the message only — never the request (which carries the bearer key).
      logger.error("OpenAI request threw", {
        message: e instanceof Error ? e.message : String(e),
      });
      throw new HttpsError("unavailable", "Generation service unavailable.");
    }

    if (!res.ok) {
      logger.error("OpenAI non-OK", {status: res.status});
      throw new HttpsError("internal", "Generation failed.");
    }

    const body = (await res.json()) as any;
    const content = body?.choices?.[0]?.message?.content;
    if (typeof content !== "string") {
      throw new HttpsError("internal", "Empty model response.");
    }
    try {
      return sanitize(JSON.parse(content));
    } catch (e) {
      if (e instanceof HttpsError) throw e; // keep mapped errors (e.g. no days)
      logger.error("Failed to parse/sanitize model output");
      throw new HttpsError("internal", "Model returned a malformed program.");
    }
  },
);
