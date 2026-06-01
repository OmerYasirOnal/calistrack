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

interface ProgramExercise {
  exerciseId: string;
  targetSets: number;
  targetReps?: number;
  targetHoldSeconds?: number;
  targetDistanceMeters?: number;
  targetDurationSeconds?: number;
}

/** Keep only movements with a known id and at least one valid target. */
function sanitize(program: any): any {
  const days = Array.isArray(program?.days) ? program.days : [];
  const cleanDays = days
    .map((d: any) => ({
      label: String(d?.label ?? "Day"),
      exercises: (Array.isArray(d?.exercises) ? d.exercises : [])
        .filter((e: ProgramExercise) => EXERCISE_IDS.includes(e?.exerciseId))
        .map((e: ProgramExercise) => ({
          exerciseId: e.exerciseId,
          targetSets: Math.max(1, Math.round(e.targetSets ?? 3)),
          ...(e.targetReps != null ? {targetReps: e.targetReps} : {}),
          ...(e.targetHoldSeconds != null ?
            {targetHoldSeconds: e.targetHoldSeconds} : {}),
          ...(e.targetDistanceMeters != null ?
            {targetDistanceMeters: e.targetDistanceMeters} : {}),
          ...(e.targetDurationSeconds != null ?
            {targetDurationSeconds: e.targetDurationSeconds} : {}),
        })),
    }))
    .filter((d: any) => d.exercises.length > 0);

  if (cleanDays.length === 0) {
    throw new HttpsError("internal", "Model returned no usable days.");
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
          response_format: {type: "json_object"},
          messages: [
            {role: "system", content: systemPrompt()},
            {role: "user", content: userMsg},
          ],
        }),
      });
    } catch (e) {
      logger.error("OpenAI request threw", e);
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
    return sanitize(JSON.parse(content));
  },
);
