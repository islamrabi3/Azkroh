"use client";

import { useEffect, useState } from "react";
import { CATEGORIES, supabase } from "@/lib/supabase";
import { Icon, PageHeader } from "@/lib/ui";
import type { Notify, Tab } from "../page";

type Counts = Record<string, number>;

async function count(table: string, filters: Record<string, string> = {}) {
  let q = supabase.from(table).select("id", { count: "exact", head: true });
  for (const [k, v] of Object.entries(filters)) q = q.eq(k, v);
  const { count } = await q;
  return count ?? 0;
}

export default function Overview({ go, notify }: { go: (t: Tab) => void; notify: Notify }) {
  const [s, setS] = useState<Counts | null>(null);
  const [cats, setCats] = useState<Counts>({});

  useEffect(() => {
    (async () => {
      const [approved, pending, content, reciters] = await Promise.all([
        count("questions", { status: "approved" }),
        count("questions", { status: "pending" }),
        count("content_items", { is_published: "true" }),
        count("reciters"),
      ]);
      setS({ approved, pending, content, reciters });
      const entries = await Promise.all(
        Object.keys(CATEGORIES).map(async (k) =>
          [k, await count("questions", { category: k, status: "approved" })] as const),
      );
      setCats(Object.fromEntries(entries));
    })();
  }, []);

  async function bump(key: string, label: string) {
    const { data } = await supabase.from("app_config").select("value").eq("key", key).single();
    const next = (Number(data?.value) || 0) + 1;
    const { error } = await supabase.from("app_config").update({ value: next }).eq("key", key);
    notify(error ? error.message : `تم إبلاغ التطبيق بتحديث ${label}`, !error);
  }

  const max = Math.max(1, ...Object.values(cats));

  return (
    <>
      <PageHeader title="أهلاً بك 👋" subtitle="ملخص محتوى تطبيق أذكروه" />

      <div className="stats">
        <Stat ico="quiz" tone="g" value={s?.approved} label="سؤال معتمد في المسابقة" />
        <Stat ico="check" tone="y" value={s?.pending} label="بانتظار مراجعتك" onClick={() => go("questions")} />
        <Stat ico="play" tone="b" value={s?.content} label="فيديو ورابط منشور" onClick={() => go("content")} />
        <Stat ico="mic" tone="r" value={s?.reciters} label="قارئ مضاف" onClick={() => go("reciters")} />
      </div>

      <div className="grid-2">
        <div className="card">
          <div className="card-title"><Icon name="book" size={18} /> الأسئلة المعتمدة حسب القسم</div>
          <div className="bars">
            {Object.entries(CATEGORIES).map(([k, v]) => (
              <div className="bar-row" key={k}>
                <span>{v}</span>
                <div className="bar"><i style={{ width: `${((cats[k] ?? 0) / max) * 100}%` }} /></div>
                <b>{cats[k] ?? "…"}</b>
              </div>
            ))}
          </div>
        </div>

        <div className="stack">
          <div className="card">
            <div className="card-title"><Icon name="sparkle" size={18} /> إجراءات سريعة</div>
            <div className="stack" style={{ gap: 10 }}>
              <button className="btn gold" onClick={() => go("generate")}>
                <Icon name="sparkle" size={18} /> ولّد أسئلة جديدة بالذكاء الاصطناعي
              </button>
              <button className="btn ghost" onClick={() => go("content")}>
                <Icon name="plus" size={18} /> أضف فيديو أو رابطاً للصفحة الرئيسية
              </button>
              <button className="btn ghost" onClick={() => go("reciters")}>
                <Icon name="upload" size={18} /> ارفع تلاوات قارئ
              </button>
            </div>
          </div>
          <div className="card">
            <div className="card-title"><Icon name="refresh" size={18} /> تحديث التطبيق فوراً</div>
            <p style={{ margin: "0 0 12px", color: "var(--muted)", fontSize: 14 }}>
              ما تعتمده أو تنشره يصل للتطبيق تلقائياً، وهذه الأزرار تجعل التطبيق يحدّث نسخته المحفوظة فوراً.
            </p>
            <div className="row">
              <button className="btn ghost sm" onClick={() => bump("questions_version", "الأسئلة")}>تحديث الأسئلة</button>
              <button className="btn ghost sm" onClick={() => bump("content_version", "المحتوى")}>تحديث المحتوى</button>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

function Stat({ ico, tone, value, label, onClick }: {
  ico: string; tone: string; value?: number; label: string; onClick?: () => void;
}) {
  return (
    <div className="stat" style={{ cursor: onClick ? "pointer" : undefined }} onClick={onClick}>
      <div className={`ico ${tone}`}><Icon name={ico} size={22} /></div>
      <div>
        <b>{value ?? "…"}</b>
        <span>{label}</span>
      </div>
    </div>
  );
}
