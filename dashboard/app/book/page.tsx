"use client";

import { useEffect, useState } from "react";

const APP_STORE = "https://apps.apple.com/app/id6755852829";
const PLAY_STORE = "https://play.google.com/store/apps/details?id=com.islamsalemco.azkroh";

/**
 * Landing page for a book shared from the app:
 *   /book/?id=12028&t=صيد الخاطر   (Turath book)
 *   /book/?pdf=https://…&t=…       (PDF link)
 * With the app installed the phone opens this link in the app directly
 * (Universal Links / App Links), so this page is only reached without the
 * app: phones go straight to their store; computers see the buttons.
 */
export default function SharedBook() {
  const [q, setQ] = useState<URLSearchParams | null>(null);
  const [os, setOs] = useState<"ios" | "android" | "other">("other");

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setQ(params);
    const ua = navigator.userAgent;
    const kind = /android/i.test(ua) ? "android" : /iphone|ipad|ipod/i.test(ua) ? "ios" : "other";
    setOs(kind);
    if (kind === "android") {
      // Opens the app if it is there, otherwise Google Play.
      window.location.replace(
        `intent://open/book?${params.toString()}#Intent;scheme=azkroh;package=com.islamsalemco.azkroh;` +
          `S.browser_fallback_url=${encodeURIComponent(PLAY_STORE)};end`,
      );
    } else if (kind === "ios") {
      window.location.replace(APP_STORE);
    }
  }, []);

  const title = q?.get("t") || "كتاب";
  const query = q ? q.toString() : "";
  const appLink = `azkroh://open/book?${query}`;
  const intentLink =
    `intent://open/book?${query}#Intent;scheme=azkroh;package=com.islamsalemco.azkroh;` +
    `S.browser_fallback_url=${encodeURIComponent(PLAY_STORE)};end`;
  const openHref = os === "android" ? intentLink : appLink;

  return (
    <main style={s.page}>
      <div style={s.card}>
        <img src="/logo.png" alt="أذكروه" style={s.logo} />
        <div style={s.kicker}>كتاب مُشارك من تطبيق أذكروه</div>
        <div style={s.book}>
          <div style={s.bookInner}>
            <span style={s.star}>✦</span>
            <h1 style={s.title}>{title}</h1>
            <span style={s.rule} />
          </div>
        </div>
        <p style={s.text}>
          {os === "other"
            ? "اقرأ النسخة المصورة من الطبعة الورقية داخل التطبيق، مع الفهرس والعلامات والقراءة بدون إنترنت."
            : "جارٍ تحويلك إلى المتجر لتحميل التطبيق…"}
        </p>

        {q && (
          <a href={openHref} style={s.primary}>افتح الكتاب في أذكروه</a>
        )}

        <div style={s.or}>ليس عندك التطبيق؟ حمّله مجاناً</div>
        <div style={s.stores}>
          {os !== "android" && <a href={APP_STORE} style={s.store}> App Store</a>}
          {os !== "ios" && <a href={PLAY_STORE} style={s.store}>▶ Google Play</a>}
        </div>
        <p style={s.hint}>بعد تثبيت التطبيق ارجع لهذه الصفحة واضغط «افتح الكتاب في أذكروه».</p>
      </div>
    </main>
  );
}

const s: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100vh", width: "100%", boxSizing: "border-box", overflowX: "hidden",
    display: "flex", alignItems: "center", justifyContent: "center", padding: 16,
    background: "linear-gradient(180deg,#06261f 0%,#0f5c4a 55%,#f6f4ee 55%)",
    fontFamily: "system-ui, -apple-system, 'Segoe UI', Tahoma, sans-serif",
  },
  card: {
    width: "100%", maxWidth: 420, boxSizing: "border-box", background: "#fff", borderRadius: 28, padding: "28px 22px",
    textAlign: "center", boxShadow: "0 20px 50px rgba(6,38,31,.25)",
  },
  logo: { width: 64, height: 64, borderRadius: 16, marginBottom: 10 },
  kicker: { color: "#6b7772", fontSize: 13, marginBottom: 16 },
  book: {
    margin: "0 auto 18px", width: 170, height: 230, borderRadius: "6px 14px 14px 6px", padding: 10,
    background: "linear-gradient(135deg,#7a3e1d,#4e2511)", boxShadow: "0 10px 24px rgba(0,0,0,.25)",
  },
  bookInner: {
    height: "100%", border: "1px solid rgba(212,175,55,.6)", borderRadius: 4,
    display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12, padding: 10,
  },
  star: { color: "#d4af37", fontSize: 14 },
  title: { color: "#fff", fontSize: 20, lineHeight: 1.5, margin: 0, fontWeight: 800 },
  rule: { width: 34, height: 1, background: "#d4af37" },
  text: { color: "#1c2b27", fontSize: 14.5, lineHeight: 1.8, margin: "0 0 18px" },
  primary: {
    display: "block", background: "#0f5c4a", color: "#fff", textDecoration: "none", fontWeight: 800,
    padding: "15px 18px", borderRadius: 16, fontSize: 16,
  },
  or: { color: "#6b7772", fontSize: 13, margin: "18px 0 10px" },
  stores: { display: "flex", gap: 10, justifyContent: "center", flexWrap: "wrap" },
  store: {
    flex: "1 1 140px", boxSizing: "border-box", border: "1px solid #e6e1d3", borderRadius: 14, padding: "12px 10px",
    color: "#1c2b27", textDecoration: "none", fontWeight: 700, background: "#faf6ec",
  },
  hint: { color: "#8a948f", fontSize: 12, marginTop: 14, lineHeight: 1.7 },
};
