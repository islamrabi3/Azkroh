"use client";

import { useCallback, useEffect, useState } from "react";
import { CATEGORIES, Question, STATUS, supabase } from "@/lib/supabase";
import { Empty, Field, Icon, Modal, PageHeader, Skeleton } from "@/lib/ui";
import type { Notify } from "../page";

const PAGE = 15;
const DIFF: Record<number, string> = { 1: "سهل", 2: "متوسط", 3: "صعب" };

const blank = (): Partial<Question> => ({
  category: "general", difficulty: 1, question: "", options: ["", "", "", ""],
  correct: 0, explanation: "", source: "", status: "approved",
});

export default function Questions({ notify, onChange }: { notify: Notify; onChange: () => void }) {
  const [status, setStatus] = useState<string>("pending");
  const [category, setCategory] = useState("");
  const [search, setSearch] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<Question[] | null>(null);
  const [total, setTotal] = useState(0);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [sel, setSel] = useState<Set<string>>(new Set());
  const [editing, setEditing] = useState<Partial<Question> | null>(null);

  // Debounce search input.
  useEffect(() => {
    const t = setTimeout(() => { setQ(search.trim()); setPage(0); }, 300);
    return () => clearTimeout(t);
  }, [search]);

  const loadCounts = useCallback(async () => {
    const out: Record<string, number> = {};
    await Promise.all(["pending", "approved", "rejected"].map(async (s) => {
      const { count } = await supabase.from("questions").select("id", { count: "exact", head: true }).eq("status", s);
      out[s] = count ?? 0;
    }));
    setCounts(out);
    return out;
  }, []);

  const load = useCallback(async () => {
    setRows(null);
    let query = supabase.from("questions").select("*", { count: "exact" })
      .order("created_at", { ascending: false })
      .range(page * PAGE, page * PAGE + PAGE - 1);
    if (status) query = query.eq("status", status);
    if (category) query = query.eq("category", category);
    if (q) query = query.ilike("question", `%${q}%`);
    const { data, count, error } = await query;
    if (error) notify(error.message, false);
    setRows((data as Question[]) ?? []);
    setTotal(count ?? 0);
    setSel(new Set());
  }, [status, category, q, page, notify]);

  useEffect(() => { load(); }, [load]);
  // First visit: open on "approved" when nothing is waiting for review.
  useEffect(() => {
    loadCounts().then((c) => { if (!c.pending) setStatus("approved"); });
  }, [loadCounts]);

  const refresh = () => { load(); loadCounts(); onChange(); };

  async function setStatusFor(ids: string[], s: Question["status"]) {
    const { error } = await supabase.from("questions")
      .update({ status: s, approved_at: s === "approved" ? new Date().toISOString() : null })
      .in("id", ids);
    notify(error ? error.message : s === "approved" ? `تم اعتماد ${ids.length}` : `تم رفض ${ids.length}`, !error);
    refresh();
  }

  async function remove(ids: string[]) {
    if (!confirm(`حذف ${ids.length} سؤال نهائياً؟`)) return;
    const { error } = await supabase.from("questions").delete().in("id", ids);
    notify(error ? error.message : "تم الحذف", !error);
    refresh();
  }

  async function save() {
    if (!editing) return;
    const opts = (editing.options ?? []).map((o) => o.trim());
    const filled = opts.filter(Boolean);
    if (!editing.question?.trim() || filled.length < 2) {
      notify("اكتب السؤال واختيارين على الأقل", false);
      return;
    }
    const correctText = opts[editing.correct ?? 0];
    if (!correctText) {
      notify("الاختيار الصحيح فارغ", false);
      return;
    }
    const row = {
      category: editing.category, difficulty: editing.difficulty,
      question: editing.question.trim(), options: filled,
      correct: filled.indexOf(correctText),
      explanation: editing.explanation ?? "", source: editing.source ?? "", status: editing.status,
    };
    const { error } = editing.id
      ? await supabase.from("questions").update(row).eq("id", editing.id)
      : await supabase.from("questions").insert(row);
    notify(error ? error.message : "تم الحفظ", !error);
    if (!error) { setEditing(null); refresh(); }
  }

  const pages = Math.max(1, Math.ceil(total / PAGE));
  const toggle = (id: string) => {
    const s = new Set(sel);
    s.has(id) ? s.delete(id) : s.add(id);
    setSel(s);
  };

  return (
    <>
      <PageHeader title="الأسئلة" subtitle="راجع واعتمد أسئلة المسابقة. المعتمد فقط يظهر في التطبيق."
        action={<button className="btn gold" onClick={() => setEditing(blank())}><Icon name="plus" size={18} /> سؤال جديد</button>} />

      <div className="card" style={{ marginBottom: 14 }}>
        <div className="row" style={{ marginBottom: 12 }}>
          <div className="seg">
            {[["pending", "بانتظار المراجعة"], ["approved", "معتمد"], ["rejected", "مرفوض"], ["", "الكل"]].map(([k, v]) => (
              <button key={k} className={status === k ? "on" : ""} onClick={() => { setStatus(k); setPage(0); }}>
                {v}{k && <span className="n">{counts[k] ?? "…"}</span>}
              </button>
            ))}
          </div>
        </div>
        <div className="row">
          <div className="search">
            <Icon name="search" size={18} />
            <input placeholder="ابحث في نص السؤال" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <select style={{ width: 200 }} value={category} onChange={(e) => { setCategory(e.target.value); setPage(0); }}>
            <option value="">كل الأقسام</option>
            {Object.entries(CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          {rows && rows.length > 0 && (
            <label className="row" style={{ gap: 6, fontSize: 13.5, color: "var(--text-2)", cursor: "pointer" }}>
              <input type="checkbox" checked={sel.size === rows.length}
                onChange={(e) => setSel(e.target.checked ? new Set(rows.map((r) => r.id)) : new Set())} />
              تحديد الكل
            </label>
          )}
        </div>
      </div>

      {rows === null ? <Skeleton rows={4} /> : rows.length === 0 ? (
        <div className="card"><Empty icon="quiz" title="لا توجد أسئلة هنا"
          text={status === "pending" ? "لا شيء بانتظار المراجعة 🎉" : "جرّب تغيير الفلتر أو البحث"} /></div>
      ) : (
        <div className="q-list">
          {rows.map((r) => (
            <div key={r.id} className={`q-card ${sel.has(r.id) ? "sel" : ""}`}>
              <input type="checkbox" checked={sel.has(r.id)} onChange={() => toggle(r.id)} aria-label="تحديد" style={{ marginTop: 4 }} />
              <div>
                <div className="q-meta">
                  <span className="badge-s neutral">{CATEGORIES[r.category] ?? r.category}</span>
                  <span className={`badge-s ${r.status}`}>{STATUS[r.status]}</span>
                  <span className="badge-s neutral">{DIFF[r.difficulty]}</span>
                </div>
                <div className="q-text">{r.question}</div>
                <div className="q-opts">
                  {r.options.map((o, i) => <div key={i} className={i === r.correct ? "ok" : ""}>{i === r.correct ? "✓ " : ""}{o}</div>)}
                </div>
                {r.explanation && <div className="q-exp">{r.explanation}</div>}
                {r.source && <div className="q-src">المصدر: {r.source}</div>}
                <div className="q-actions">
                  {r.status !== "approved" && <button className="btn sm" onClick={() => setStatusFor([r.id], "approved")}><Icon name="check" size={16} /> اعتماد</button>}
                  {r.status !== "rejected" && <button className="btn sm ghost" onClick={() => setStatusFor([r.id], "rejected")}><Icon name="x" size={16} /> رفض</button>}
                  <button className="btn sm ghost" onClick={() => setEditing({ ...r, options: [...r.options, ...Array(Math.max(0, 4 - r.options.length)).fill("")] })}><Icon name="edit" size={16} /> تعديل</button>
                  <button className="btn sm danger" onClick={() => remove([r.id])}><Icon name="trash" size={16} /> حذف</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {sel.size > 0 && (
        <div className="bulk">
          <b>{sel.size} محدد</b>
          <span className="spacer" />
          <button className="btn sm gold" onClick={() => setStatusFor([...sel], "approved")}>اعتماد المحدد</button>
          <button className="btn sm ghost" onClick={() => setStatusFor([...sel], "rejected")}>رفض</button>
          <button className="btn sm ghost" onClick={() => remove([...sel])}>حذف</button>
        </div>
      )}

      {rows && total > PAGE && (
        <div className="pager">
          <button className="btn ghost sm" disabled={page === 0} onClick={() => setPage(page - 1)}>السابق</button>
          <span>صفحة {page + 1} من {pages} • {total} سؤال</span>
          <button className="btn ghost sm" disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>التالي</button>
        </div>
      )}

      {editing && (
        <Modal title={editing.id ? "تعديل السؤال" : "سؤال جديد"} onClose={() => setEditing(null)} wide
          footer={<>
            <button className="btn ghost" onClick={() => setEditing(null)}>إلغاء</button>
            <button className="btn" onClick={save}>حفظ</button>
          </>}>
          <div className="stack">
            <div className="grid-3">
              <Field label="القسم">
                <select value={editing.category} onChange={(e) => setEditing({ ...editing, category: e.target.value })}>
                  {Object.entries(CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
              </Field>
              <Field label="الصعوبة">
                <select value={editing.difficulty} onChange={(e) => setEditing({ ...editing, difficulty: Number(e.target.value) })}>
                  {Object.entries(DIFF).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
              </Field>
              <Field label="الحالة">
                <select value={editing.status} onChange={(e) => setEditing({ ...editing, status: e.target.value as Question["status"] })}>
                  {Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
              </Field>
            </div>
            <Field label="نص السؤال">
              <textarea value={editing.question} onChange={(e) => setEditing({ ...editing, question: e.target.value })} />
            </Field>
            <Field label="الاختيارات" hint="اختر الإجابة الصحيحة بالدائرة بجانبها. اترك الخانة فارغة لحذفها.">
              <div className="stack" style={{ gap: 8 }}>
                {(editing.options ?? []).map((o, i) => (
                  <div className="option-row" key={i}>
                    <label className="radio">
                      <input type="radio" name="correct" checked={editing.correct === i}
                        onChange={() => setEditing({ ...editing, correct: i })} /> صحيح
                    </label>
                    <input value={o} placeholder={`الاختيار ${i + 1}`} onChange={(e) => {
                      const opts = [...(editing.options ?? [])];
                      opts[i] = e.target.value;
                      setEditing({ ...editing, options: opts });
                    }} />
                  </div>
                ))}
              </div>
            </Field>
            <Field label="الشرح (يظهر للاعبين بعد السؤال)">
              <textarea value={editing.explanation ?? ""} onChange={(e) => setEditing({ ...editing, explanation: e.target.value })} />
            </Field>
            <Field label="المصدر">
              <input value={editing.source ?? ""} placeholder="مثال: صحيح البخاري، أو سورة البقرة: 255"
                onChange={(e) => setEditing({ ...editing, source: e.target.value })} />
            </Field>
          </div>
        </Modal>
      )}
    </>
  );
}
