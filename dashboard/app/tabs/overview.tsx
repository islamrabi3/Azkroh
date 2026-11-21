"use client";

import { useEffect, useState } from "react";
import { CATEGORIES, supabase } from "@/lib/supabase";

type Counts = Record<string, number>;

export default function Overview() {
  const [status, setStatus] = useState<Counts>({});
  const [cats, setCats] = useState<Counts>({});
  const [content, setContent] = useState(0);
  const [reciters, setReciters] = useState(0);
  const [msg, setMsg] = useState("");

  async function count(table: string, col?: string, val?: string) {
    let q = supabase.from(table).select("id", { count: "exact", head: true });
    if (col && val) q = q.eq(col, val);
    const { count } = await q;
    return count ?? 0;
  }

  useEffect(() => {
    (async () => {
      const s: Counts = {};
      for (const k of ["approved", "pending", "rejected"]) {
        s[k] = await count("questions", "status", k);
      }
      setStatus(s);
      const c: Counts = {};
      for (const k of Object.keys(CATEGORIES)) {
        const { count: n } = await supabase
          .from("questions")
          .select("id", { count: "exact", head: true })
          .eq("category", k)
          .eq("status", "approved");
        c[k] = n ?? 0;
      }
      setCats(c);
      setContent(await count("content_items"));
      setReciters(await count("reciters"));
    })();
  }, []);

  async function bump(key: string) {
    const { data } = await supabase.from("app_config").select("value").eq("key", key).single();
    const next = (Number(data?.value) || 0) + 1;
    const { error } = await supabase.from("app_config").update({ value: next }).eq("key", key);
    setMsg(error ? error.message : `تم إرسال التحديث للتطبيق (الإصدار ${next})`);
  }

  return (
    <>
      <div className="stats">
        <div className="stat"><b>{status.approved ?? "…"}</b><span>أسئلة معتمدة تظهر في اللعبة</span></div>
        <div className="stat"><b>{status.pending ?? "…"}</b><span>بانتظار مراجعتك</span></div>
        <div className="stat"><b>{status.rejected ?? "…"}</b><span>مرفوضة</span></div>
        <div className="stat"><b>{content}</b><span>عناصر محتوى</span></div>
        <div className="stat"><b>{reciters}</b><span>قراء مضافون</span></div>
      </div>

      <div className="card" style={{ marginTop: 14 }}>
        <h3 style={{ marginTop: 0 }}>الأسئلة المعتمدة حسب القسم</h3>
        <table>
          <tbody>
            {Object.entries(CATEGORIES).map(([k, v]) => (
              <tr key={k}><td>{v}</td><td><b>{cats[k] ?? "…"}</b></td></tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h3 style={{ marginTop: 0 }}>نشر التحديثات للتطبيق</h3>
        <p className="muted">
          أي سؤال تعتمده أو محتوى تنشره يظهر في التطبيق تلقائياً. هذه الأزرار تُعلم التطبيق
          بوجود جديد ليحدّث نسخته المحفوظة فوراً.
        </p>
        {msg && <div className="msg ok">{msg}</div>}
        <div className="row">
          <button className="fit" onClick={() => bump("questions_version")}>تحديث الأسئلة في التطبيق</button>
          <button className="fit gold" onClick={() => bump("content_version")}>تحديث المحتوى في التطبيق</button>
        </div>
      </div>
    </>
  );
}
