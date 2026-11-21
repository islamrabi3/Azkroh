"use client";

import { useState } from "react";
import { CATEGORIES, supabase } from "@/lib/supabase";

export default function Generate({ onDone }: { onDone: () => void }) {
  const [category, setCategory] = useState("seerah");
  const [count, setCount] = useState(10);
  const [difficulty, setDifficulty] = useState(0);
  const [topic, setTopic] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  async function run() {
    setBusy(true);
    setMsg(null);
    const { data, error } = await supabase.functions.invoke("generate-questions", {
      body: { category, count, topic, difficulty: difficulty || undefined },
    });
    setBusy(false);
    if (error) {
      let text = "تعذر التوليد";
      try {
        const ctx = (error as { context?: Response }).context;
        const body = ctx ? await ctx.json() : null;
        text = body?.message ?? body?.error ?? text;
      } catch {}
      setMsg({ ok: false, text });
      return;
    }
    setMsg({
      ok: true,
      text: `تم توليد ${data?.inserted ?? 0} سؤال، وهي الآن «بانتظار المراجعة» في تبويب الأسئلة.`,
    });
  }

  return (
    <div className="card">
      <h3 style={{ marginTop: 0 }}>توليد أسئلة جديدة باستخدام Claude</h3>
      <p className="muted">
        تُحفظ الأسئلة المولّدة «بانتظار المراجعة» ولا تظهر في التطبيق إلا بعد اعتمادك لها.
        كل طلب يستهلك رصيداً من حساب Claude API.
      </p>
      <div className="row">
        <div>
          <label>القسم</label>
          <select value={category} onChange={(e) => setCategory(e.target.value)}>
            {Object.entries(CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
        <div>
          <label>عدد الأسئلة (حتى 25)</label>
          <input type="number" min={1} max={25} value={count}
            onChange={(e) => setCount(Math.min(25, Math.max(1, Number(e.target.value))))} />
        </div>
        <div>
          <label>الصعوبة</label>
          <select value={difficulty} onChange={(e) => setDifficulty(Number(e.target.value))}>
            <option value={0}>متنوعة</option><option value={1}>سهل</option>
            <option value={2}>متوسط</option><option value={3}>صعب</option>
          </select>
        </div>
      </div>
      <label>موضوع محدد (اختياري)</label>
      <input value={topic} placeholder="مثال: غزوة بدر، أو سيرة عمر بن الخطاب"
        onChange={(e) => setTopic(e.target.value)} />
      <div className="row" style={{ marginTop: 14 }}>
        <button className="fit gold" disabled={busy} onClick={run}>
          {busy ? "جاري التوليد... (قد يستغرق دقيقة)" : "ولّد الأسئلة"}
        </button>
        {msg?.ok && <button className="fit ghost" onClick={onDone}>راجع الأسئلة الآن</button>}
      </div>
      {msg && <div className={`msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</div>}
    </div>
  );
}
