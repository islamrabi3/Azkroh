"use client";

import { useState } from "react";
import { CATEGORIES, supabase } from "@/lib/supabase";
import { Field, Icon, PageHeader } from "@/lib/ui";
import type { Notify, Tab } from "../page";

export default function Generate({ notify, go }: { notify: Notify; go: (t: Tab) => void }) {
  const [category, setCategory] = useState("seerah");
  const [count, setCount] = useState(10);
  const [difficulty, setDifficulty] = useState(0);
  const [topic, setTopic] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<number | null>(null);
  const [err, setErr] = useState("");

  async function run() {
    setBusy(true);
    setErr("");
    setDone(null);
    const { data, error } = await supabase.functions.invoke("generate-questions", {
      body: { category, count, topic, difficulty: difficulty || undefined },
    });
    setBusy(false);
    if (error) {
      let text = "تعذر التوليد، حاول مرة أخرى";
      try {
        const ctx = (error as { context?: Response }).context;
        const body = ctx ? await ctx.json() : null;
        text = body?.message ?? text;
      } catch {}
      setErr(text);
      return;
    }
    setDone(data?.inserted ?? 0);
    notify(`تم توليد ${data?.inserted ?? 0} سؤال`);
  }

  return (
    <>
      <PageHeader title="توليد أسئلة بالذكاء الاصطناعي"
        subtitle="يكتب Claude أسئلة جديدة بمصادرها، وتصلك للمراجعة قبل أن تظهر في التطبيق." />

      <div className="grid-2" style={{ alignItems: "start" }}>
        <div className="card stack">
          <div className="grid-2">
            <Field label="القسم">
              <select value={category} onChange={(e) => setCategory(e.target.value)}>
                {Object.entries(CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
            </Field>
            <Field label="الصعوبة">
              <select value={difficulty} onChange={(e) => setDifficulty(Number(e.target.value))}>
                <option value={0}>متنوعة</option><option value={1}>سهل</option>
                <option value={2}>متوسط</option><option value={3}>صعب</option>
              </select>
            </Field>
          </div>
          <Field label={`عدد الأسئلة: ${count}`}>
            <input type="range" min={5} max={25} step={5} value={count} style={{ height: 24, padding: 0 }}
              onChange={(e) => setCount(Number(e.target.value))} />
          </Field>
          <Field label="موضوع محدد (اختياري)" hint="مثال: غزوة بدر، سيرة عمر بن الخطاب، أركان الصلاة">
            <input value={topic} onChange={(e) => setTopic(e.target.value)} />
          </Field>
          <button className="btn gold" style={{ height: 46 }} disabled={busy} onClick={run}>
            {busy ? <><span className="spin"><Icon name="refresh" size={18} /></span> جاري التوليد... قد يستغرق دقيقة</> :
              <><Icon name="sparkle" size={18} /> ولّد {count} سؤالاً</>}
          </button>
          {err && <div className="alert">{err}</div>}
          {done !== null && (
            <div className="note">
              <Icon name="check" size={18} />
              <div style={{ flex: 1 }}>تم توليد {done} سؤال وهي الآن بانتظار مراجعتك.</div>
              <button className="btn sm" onClick={() => go("questions")}>راجعها الآن</button>
            </div>
          )}
        </div>

        <div className="stack">
          <div className="note">
            <Icon name="check" size={18} />
            <div>الأسئلة المولّدة لا تظهر للمستخدمين إلا بعد اعتمادك لها من صفحة «الأسئلة».</div>
          </div>
          <div className="note">
            <Icon name="book" size={18} />
            <div>يُطلب من Claude الاعتماد على القرآن والأحاديث الصحيحة وكتب السيرة المعتمدة، وتجنب الخلافيات والإسرائيليات، مع ذكر المصدر لكل سؤال.</div>
          </div>
          <div className="note warn">
            <Icon name="sparkle" size={18} />
            <div>كل عملية توليد تستهلك رصيداً من حساب Claude API. يجب إضافة المفتاح مرة واحدة في Supabase باسم ANTHROPIC_API_KEY.</div>
          </div>
        </div>
      </div>
    </>
  );
}
