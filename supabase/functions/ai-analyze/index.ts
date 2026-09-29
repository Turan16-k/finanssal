// Kullanıcının yapıştırdığı finansal bülteni Gemini ile özetler ve duygu skoru üretir.
//
// Güvenlik katmanları:
//   1. Supabase JWT (verify_jwt = true) -> yalnızca oturumlu kullanıcılar (anonim dahil).
//   2. Firebase App Check token'ı (APP_CHECK_ENFORCE=true iken zorunlu) -> yalnızca gerçek uygulama.
//   3. Kullanıcı başına günlük kota (AI_DAILY_LIMIT, varsayılan 10).
// Gemini anahtarı yalnızca burada (secret) durur, uygulamaya hiç gitmez.
//
// Not: Gemini ücretsiz katmanında gönderilen içerik Google tarafından ürün geliştirme için
// kullanılabilir. Bu yüzden kullanıcı kimliği/kişisel veri gönderilmez; uygulama kullanıcıyı
// bu konuda bilgilendirir.
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";
import { createClient } from "npm:@supabase/supabase-js@2";
import { adminClient, json } from "../_shared/supabase.ts";

const MAX_CHARS = 8000;
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "10");
const APP_CHECK_JWKS = createRemoteJWKSet(new URL("https://firebaseappcheck.googleapis.com/v1/jwks"));

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    summary: { type: "STRING", description: "En fazla 3 cümlelik Türkçe özet" },
    sentiment: { type: "NUMBER", description: "-1 (çok olumsuz) ile 1 (çok olumlu) arası" },
    label: { type: "STRING", enum: ["negatif", "nötr", "pozitif"] },
    key_points: { type: "ARRAY", items: { type: "STRING" }, description: "En fazla 4 madde" },
    mentioned_assets: { type: "ARRAY", items: { type: "STRING" }, description: "Geçen varlık/sembol adları" },
  },
  required: ["summary", "sentiment", "label", "key_points", "mentioned_assets"],
};

const PROMPT = `Sen bir finansal metin analistisin. Aşağıdaki bülteni analiz et.
Kurallar: Yatırım tavsiyesi verme, al/sat önerme. Yalnızca metinde yazanı özetle.
Duygu skoru metnin piyasalar için genel tonunu yansıtsın.

BÜLTEN:
"""
{TEXT}
"""`;

async function verifyAppCheck(req: Request): Promise<boolean> {
  if (Deno.env.get("APP_CHECK_ENFORCE") !== "true") return true;
  const token = req.headers.get("X-Firebase-AppCheck");
  const projectNumber = Deno.env.get("FIREBASE_PROJECT_NUMBER");
  if (!token || !projectNumber) return false;
  try {
    await jwtVerify(token, APP_CHECK_JWKS, {
      issuer: `https://firebaseappcheck.googleapis.com/${projectNumber}`,
      audience: `projects/${projectNumber}`,
      algorithms: ["RS256"],
    });
    return true;
  } catch {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "yalnızca POST" }, 405);
  if (!(await verifyAppCheck(req))) return json({ error: "uygulama doğrulanamadı" }, 401);

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "oturum yok" }, 401);

  let text: string;
  try {
    ({ text } = await req.json());
  } catch {
    return json({ error: "geçersiz gövde" }, 400);
  }
  text = (text ?? "").toString().trim();
  if (text.length < 20) return json({ error: "metin çok kısa" }, 400);
  if (text.length > MAX_CHARS) text = text.slice(0, MAX_CHARS);

  const db = adminClient();
  const { data: allowed, error: quotaErr } = await db.rpc("consume_ai_quota", {
    p_user: user.id,
    p_daily_limit: DAILY_LIMIT,
  });
  if (quotaErr) return json({ error: quotaErr.message }, 500);
  if (!allowed) return json({ error: "günlük AI kotası doldu", limit: DAILY_LIMIT }, 429);

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")!,
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: PROMPT.replace("{TEXT}", text) }] }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
        },
      }),
    },
  );
  if (!res.ok) {
    console.error("Gemini hata", res.status, await res.text());
    return json({ error: "AI servisi şu an yanıt vermiyor" }, 502);
  }
  const body = await res.json();
  try {
    const out = JSON.parse(body.candidates[0].content.parts[0].text);
    out.sentiment = Math.max(-1, Math.min(1, Number(out.sentiment) || 0));
    return json({ ...out, model: MODEL });
  } catch {
    return json({ error: "AI yanıtı çözümlenemedi" }, 502);
  }
});
