// Firebase Cloud Messaging HTTP v1 gönderimi (Spark/ücretsiz planda kullanılabilir).
// Gerekli secret: FIREBASE_SERVICE_ACCOUNT (Firebase Console > Proje Ayarları >
// Hizmet hesapları > Yeni özel anahtar oluştur; JSON'un tamamı tek satır olarak).
import { importPKCS8, SignJWT } from "npm:jose@5";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cached: { token: string; exp: number } | null = null;

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT tanımlı değil");
  return JSON.parse(raw);
}

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;
  const key = await importPKCS8(sa.private_key, "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`OAuth token alınamadı: ${res.status} ${await res.text()}`);
  const body = await res.json();
  cached = { token: body.access_token, exp: now + body.expires_in };
  return cached.token;
}

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export type SendOutcome = "sent" | "invalid_token" | "error";

export async function sendPush(msg: PushMessage): Promise<SendOutcome> {
  const sa = serviceAccount();
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await accessToken(sa)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: msg.token,
          notification: { title: msg.title, body: msg.body },
          data: msg.data ?? {},
          android: { priority: "HIGH", notification: { channel_id: "price_alerts" } },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    },
  );
  if (res.ok) return "sent";
  const text = await res.text();
  // Uygulama kaldırılmış / token yenilenmiş: cihaz kaydı silinmeli.
  // (INVALID_ARGUMENT bilerek dahil değil: yük hatası da olabilir, geçerli token silinmemeli.)
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    return "invalid_token";
  }
  console.error("FCM hata", res.status, text);
  return "error";
}
