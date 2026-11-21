// Generates quiz questions with Claude and stores them as "pending"
// (they reach the app only after an admin approves them in the dashboard).
//
// Secrets (Supabase → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY  – the Claude API key (never shipped to the dashboard)
// Provided automatically: SUPABASE_URL, SUPABASE_ANON_KEY.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "npm:@anthropic-ai/sdk@1.6.0";
import { createClient } from "npm:@supabase/supabase-js@2.119.0";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CATEGORIES: Record<string, string> = {
  seerah: "سيرة النبي ﷺ",
  companions: "الصحابة رضي الله عنهم",
  battles: "الغزوات",
  quran: "القرآن الكريم وعلومه",
  prophets: "قصص الأنبياء عليهم السلام",
  general: "معلومات دينية عامة (العقيدة والفقه الميسر والآداب)",
};

const SCHEMA = {
  type: "object",
  properties: {
    questions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          question: { type: "string" },
          options: { type: "array", items: { type: "string" } },
          correct: { type: "integer" },
          explanation: { type: "string" },
          source: { type: "string" },
          difficulty: { type: "integer" },
        },
        required: [
          "question",
          "options",
          "correct",
          "explanation",
          "source",
          "difficulty",
        ],
        additionalProperties: false,
      },
    },
  },
  required: ["questions"],
  additionalProperties: false,
};

const SYSTEM = `أنت معدّ أسئلة مسابقات إسلامية لتطبيق «أذكروه».
اكتب أسئلة صحيحة علمياً بالعربية الفصحى الواضحة، مناسبة لعامة المسلمين.
- اعتمد فقط على القرآن الكريم، والأحاديث الصحيحة (البخاري ومسلم وما صححه أهل العلم)، وكتب السيرة المعتمدة.
- تجنب المسائل الخلافية بين المذاهب، والإسرائيليات، والروايات الضعيفة أو الموضوعة.
- لكل سؤال 4 اختيارات مختلفة ومعقولة، واحد فقط صحيح بلا لبس.
- "correct" هو رقم الاختيار الصحيح بدءاً من 0، ونوّع موضعه بين الأسئلة.
- "explanation" شرح قصير (جملة أو جملتان) يوضح الإجابة الصحيحة.
- "source" مرجع محدد: سورة ورقم الآية، أو الحديث ومن رواه، أو كتاب السيرة.
- "difficulty": 1 سهل، 2 متوسط، 3 صعب.
- لا تكرر أسئلة شائعة أو مكررة من القائمة التي تُعطى لك.`;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  // Act as the calling user so RLS applies; only admins may continue.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: isAdmin, error: adminErr } = await supabase.rpc("is_admin");
  if (adminErr || isAdmin !== true) return json({ error: "forbidden" }, 403);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return json({
      error: "missing_key",
      message: "أضف ANTHROPIC_API_KEY في Supabase → Edge Functions → Secrets",
    }, 500);
  }

  let body: { category?: string; count?: number; topic?: string; difficulty?: number };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const category = body.category ?? "general";
  if (!CATEGORIES[category]) return json({ error: "bad_category" }, 400);
  const count = Math.min(Math.max(Number(body.count) || 10, 1), 25);
  const topic = (body.topic ?? "").toString().slice(0, 200);
  const difficulty = [1, 2, 3].includes(Number(body.difficulty))
    ? Number(body.difficulty)
    : null;

  // Recent questions of this category, to avoid duplicates.
  const { data: existing } = await supabase
    .from("questions")
    .select("question")
    .eq("category", category)
    .order("created_at", { ascending: false })
    .limit(150);
  const avoid = (existing ?? []).map((r) => `- ${r.question}`).join("\n");

  const prompt = `اكتب ${count} سؤالاً في قسم: ${CATEGORIES[category]}.
${topic ? `ركّز على: ${topic}.` : ""}
${difficulty ? `مستوى الصعوبة: ${difficulty}.` : "نوّع مستوى الصعوبة."}

أسئلة موجودة بالفعل لا تكررها:
${avoid || "(لا يوجد)"}`;

  const client = new Anthropic({ apiKey });
  let response;
  try {
    response = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "high",
        format: { type: "json_schema", schema: SCHEMA },
      },
      system: SYSTEM,
      messages: [{ role: "user", content: prompt }],
    // deno-lint-ignore no-explicit-any
    } as any);
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) {
      return json({ error: "rate_limited", message: "حاول بعد قليل" }, 429);
    }
    if (e instanceof Anthropic.AuthenticationError) {
      return json({ error: "bad_key", message: "مفتاح Claude غير صحيح" }, 500);
    }
    if (e instanceof Anthropic.APIError) {
      return json({ error: "claude_error", message: e.message }, 502);
    }
    throw e;
  }

  if (response.stop_reason === "refusal") {
    return json({ error: "refusal" }, 422);
  }
  if (response.stop_reason === "max_tokens") {
    return json({ error: "too_long", message: "قلل عدد الأسئلة" }, 422);
  }
  const text = response.content
    // deno-lint-ignore no-explicit-any
    .filter((b: any) => b.type === "text")
    // deno-lint-ignore no-explicit-any
    .map((b: any) => b.text)
    .join("");

  let parsed: { questions: Array<Record<string, unknown>> };
  try {
    parsed = JSON.parse(text);
  } catch {
    return json({ error: "parse" }, 502);
  }

  const rows = parsed.questions
    .filter((q) => {
      const opts = q.options as unknown;
      const c = q.correct as number;
      return typeof q.question === "string" && (q.question as string).length > 5 &&
        Array.isArray(opts) && opts.length >= 2 && opts.length <= 6 &&
        Number.isInteger(c) && c >= 0 && c < opts.length;
    })
    .map((q) => ({
      category,
      difficulty: Math.min(Math.max(Number(q.difficulty) || 2, 1), 3),
      question: (q.question as string).trim(),
      options: (q.options as string[]).map((o) => o.trim()),
      correct: q.correct as number,
      explanation: String(q.explanation ?? "").trim(),
      source: `claude: ${String(q.source ?? "").trim()}`.slice(0, 500),
      status: "pending",
    }));

  if (rows.length === 0) return json({ error: "empty" }, 502);

  const { data: inserted, error: insErr } = await supabase
    .from("questions")
    .insert(rows)
    .select("id");
  if (insErr) return json({ error: "insert", message: insErr.message }, 500);

  return json({ inserted: inserted?.length ?? 0 });
});
