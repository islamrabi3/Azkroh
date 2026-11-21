"use client";

import { useCallback, useEffect, useState } from "react";
import { CATEGORIES, Question, STATUS, supabase } from "@/lib/supabase";

const PAGE = 20;

const empty = (): Partial<Question> => ({
  category: "general",
  difficulty: 1,
  question: "",
  options: ["", "", "", ""],
  correct: 0,
  explanation: "",
  source: "",
  status: "approved",
});

export default function Questions() {
  const [status, setStatus] = useState("pending");
  const [category, setCategory] = useState("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<Question[]>([]);
  const [total, setTotal] = useState(0);
  const [editing, setEditing] = useState<Partial<Question> | null>(null);
  const [msg, setMsg] = useState("");

  const load = useCallback(async () => {
    let q = supabase
      .from("questions")
      .select("*", { count: "exact" })
      .order("created_at", { ascending: false })
      .range(page * PAGE, page * PAGE + PAGE - 1);
    if (status) q = q.eq("status", status);
    if (category) q = q.eq("category", category);
    if (search.trim()) q = q.ilike("question", `%${search.trim()}%`);
    const { data, count, error } = await q;
    if (error) setMsg(error.message);
    setRows((data as Question[]) ?? []);
    setTotal(count ?? 0);
  }, [status, category, search, page]);

  useEffect(() => {
    load();
  }, [load]);

  async function setRowStatus(ids: string[], s: Question["status"]) {
    const { error } = await supabase
      .from("questions")
      .update({ status: s, approved_at: s === "approved" ? new Date().toISOString() : null })
      .in("id", ids);
    setMsg(error ? error.message : `تم (${ids.length})`);
    load();
  }

  async function remove(id: string) {
    if (!confirm("حذف السؤال نهائياً؟")) return;
    const { error } = await supabase.from("questions").delete().eq("id", id);
    setMsg(error ? error.message : "تم الحذف");
    load();
  }

  async function save() {
    if (!editing) return;
    const opts = (editing.options ?? []).map((o) => o.trim()).filter(Boolean);
    if (!editing.question?.trim() || opts.length < 2) {
      setMsg("اكتب السؤال واختيارين على الأقل");
      return;
    }
    const row = {
      category: editing.category,
      difficulty: editing.difficulty,
      question: editing.question.trim(),
      options: opts,
      correct: Math.min(editing.correct ?? 0, opts.length - 1),
      explanation: editing.explanation ?? "",
      source: editing.source ?? "",
      status: editing.status,
    };
    const { error } = editing.id
      ? await supabase.from("questions").update(row).eq("id", editing.id)
      : await supabase.from("questions").insert(row);
    setMsg(error ? error.message : "تم الحفظ");
    if (!error) setEditing(null);
    load();
  }

  const pages = Math.max(1, Math.ceil(total / PAGE));

  return (
    <>
      <div className="card">
        <div className="row">
          <select value={status} onChange={(e) => { setStatus(e.target.value); setPage(0); }}>
            <option value="">كل الحالات</option>
            {Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <select value={category} onChange={(e) => { setCategory(e.target.value); setPage(0); }}>
            <option value="">كل الأقسام</option>
            {Object.entries(CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <input placeholder="بحث في نص السؤال" value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(0); }} />
          <button className="fit gold" onClick={() => setEditing(empty())}>+ سؤال جديد</button>
        </div>
        <div className="row" style={{ marginTop: 10 }}>
          <span className="muted">{total} سؤال</span>
          {status === "pending" && rows.length > 0 && (
            <button className="fit small" onClick={() => setRowStatus(rows.map((r) => r.id), "approved")}>
              اعتماد كل أسئلة هذه الصفحة
            </button>
          )}
        </div>
        {msg && <div className="msg ok">{msg}</div>}
      </div>

      {editing && (
        <div className="card" style={{ borderColor: "var(--gold)" }}>
          <h3 style={{ marginTop: 0 }}>{editing.id ? "تعديل سؤال" : "سؤال جديد"}</h3>
          <div className="row">
            <div>
              <label>القسم</label>
              <select value={editing.category}
                onChange={(e) => setEditing({ ...editing, category: e.target.value })}>
                {Object.entries(CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
            </div>
            <div>
              <label>الصعوبة</label>
              <select value={editing.difficulty}
                onChange={(e) => setEditing({ ...editing, difficulty: Number(e.target.value) })}>
                <option value={1}>سهل</option><option value={2}>متوسط</option><option value={3}>صعب</option>
              </select>
            </div>
            <div>
              <label>الحالة</label>
              <select value={editing.status}
                onChange={(e) => setEditing({ ...editing, status: e.target.value as Question["status"] })}>
                {Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
            </div>
          </div>
          <label>السؤال</label>
          <textarea value={editing.question}
            onChange={(e) => setEditing({ ...editing, question: e.target.value })} />
          <label>الاختيارات (اختر الصحيح)</label>
          {(editing.options ?? []).map((o, i) => (
            <div className="row" key={i} style={{ marginBottom: 6 }}>
              <input className="fit" type="radio" name="correct" style={{ width: 20 }}
                checked={editing.correct === i}
                onChange={() => setEditing({ ...editing, correct: i })} />
              <input value={o} placeholder={`اختيار ${i + 1}`}
                onChange={(e) => {
                  const opts = [...(editing.options ?? [])];
                  opts[i] = e.target.value;
                  setEditing({ ...editing, options: opts });
                }} />
            </div>
          ))}
          <label>الشرح</label>
          <textarea value={editing.explanation ?? ""}
            onChange={(e) => setEditing({ ...editing, explanation: e.target.value })} />
          <label>المصدر</label>
          <input value={editing.source ?? ""}
            onChange={(e) => setEditing({ ...editing, source: e.target.value })} />
          <div className="row" style={{ marginTop: 12 }}>
            <button className="fit" onClick={save}>حفظ</button>
            <button className="fit ghost" onClick={() => setEditing(null)}>إلغاء</button>
          </div>
        </div>
      )}

      {rows.map((r) => (
        <div className="card" key={r.id}>
          <div className="row">
            <span className="fit pill">{CATEGORIES[r.category] ?? r.category}</span>
            <span className={`fit pill ${r.status}`}>{STATUS[r.status]}</span>
            <span className="fit muted">صعوبة {r.difficulty}</span>
            <span />
          </div>
          <div className="q">{r.question}</div>
          <ul className="opts">
            {r.options.map((o, i) => (
              <li key={i} className={i === r.correct ? "correct" : ""}>{o}</li>
            ))}
          </ul>
          {r.explanation && <p className="muted">💡 {r.explanation}</p>}
          {r.source && <p className="muted">المصدر: {r.source}</p>}
          <div className="row">
            {r.status !== "approved" && (
              <button className="fit small" onClick={() => setRowStatus([r.id], "approved")}>اعتماد</button>
            )}
            {r.status !== "rejected" && (
              <button className="fit small ghost" onClick={() => setRowStatus([r.id], "rejected")}>رفض</button>
            )}
            <button className="fit small ghost" onClick={() => setEditing({ ...r, options: [...r.options] })}>تعديل</button>
            <button className="fit small danger" onClick={() => remove(r.id)}>حذف</button>
          </div>
        </div>
      ))}
      {rows.length === 0 && <p className="center muted">لا توجد أسئلة هنا</p>}

      <div className="pager">
        <button className="ghost small" disabled={page === 0} onClick={() => setPage(page - 1)}>السابق</button>
        <span className="muted">{page + 1} / {pages}</span>
        <button className="ghost small" disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>التالي</button>
      </div>
    </>
  );
}
