// Fiyat alarmlarını değerlendirip FCM bildirimi gönderir.
// Çağıran: pipelines/ingest.py --notify (service_role anahtarıyla), veri çekme bittikten sonra.
import { adminClient, json, safeEqual } from "../_shared/supabase.ts";
import { sendPush } from "../_shared/fcm.ts";

interface TriggeredAlert {
  alert_id: string;
  user_id: string;
  symbol: string;
  name: string;
  condition: "above" | "below" | "pct_change_up" | "pct_change_down";
  threshold: number;
  close: number;
  change_pct: number | null;
  fcm_token: string;
  locale: string;
}

const fmt = (v: number, locale: string) =>
  new Intl.NumberFormat(locale === "en" ? "en-US" : "tr-TR", { maximumFractionDigits: 4 }).format(v);

function message(a: TriggeredAlert): { title: string; body: string } {
  const en = a.locale === "en";
  const price = fmt(a.close, a.locale);
  const pct = a.change_pct == null ? "" : `${a.change_pct >= 0 ? "+" : ""}${fmt(a.change_pct, a.locale)}%`;
  switch (a.condition) {
    case "above":
      return en
        ? { title: `${a.symbol} rose above ${fmt(a.threshold, a.locale)}`, body: `${a.name}: ${price}` }
        : { title: `${a.symbol} ${fmt(a.threshold, a.locale)} üzerine çıktı`, body: `${a.name}: ${price}` };
    case "below":
      return en
        ? { title: `${a.symbol} fell below ${fmt(a.threshold, a.locale)}`, body: `${a.name}: ${price}` }
        : { title: `${a.symbol} ${fmt(a.threshold, a.locale)} altına indi`, body: `${a.name}: ${price}` };
    default:
      return en
        ? { title: `${a.symbol} moved ${pct} today`, body: `${a.name}: ${price}` }
        : { title: `${a.symbol} bugün ${pct} değişti`, body: `${a.name}: ${price}` };
  }
}

Deno.serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!serviceKey || !safeEqual(auth, `Bearer ${serviceKey}`)) {
    return json({ error: "yetkisiz" }, 401);
  }

  const db = adminClient();
  const { data, error } = await db.rpc("claim_triggered_alerts");
  if (error) return json({ error: error.message }, 500);

  const alerts = (data ?? []) as TriggeredAlert[];
  const invalidTokens = new Set<string>();
  let sent = 0, failed = 0;

  // FCM kotası cömert; yine de aşırı paralellikten kaçınmak için 20'lik gruplar.
  for (let i = 0; i < alerts.length; i += 20) {
    const batch = alerts.slice(i, i + 20);
    const outcomes = await Promise.all(batch.map((a) =>
      sendPush({
        token: a.fcm_token,
        ...message(a),
        data: { type: "price_alert", alert_id: a.alert_id, symbol: a.symbol },
      }).catch(() => "error" as const)
    ));
    outcomes.forEach((o, j) => {
      if (o === "sent") sent++;
      else {
        failed++;
        if (o === "invalid_token") invalidTokens.add(batch[j].fcm_token);
      }
    });
  }

  if (invalidTokens.size > 0) {
    await db.from("devices").delete().in("fcm_token", [...invalidTokens]);
  }
  return json({ triggered: alerts.length, sent, failed, removed_tokens: invalidTokens.size });
});
