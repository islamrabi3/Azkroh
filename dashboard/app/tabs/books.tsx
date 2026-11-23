"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabase";
import { Empty, Field, Icon, Modal, PageHeader, Skeleton } from "@/lib/ui";
import type { Notify } from "../page";

type Book = {
  id: string;
  source: "turath" | "pdf";
  turath_id: number | null;
  title: string;
  author: string | null;
  category: string | null;
  pdf_url: string | null;
  pages: number | null;
  featured: boolean;
  hidden: boolean;
  sort: number;
};

type CatalogBook = { id: number; title: string; author: string; category: string; pages: number; size: number; hasPdf: boolean };

const CATALOG_URL = "https://files.turath.io/data-v3.json";
let catalogPromise: Promise<Map<number, CatalogBook>> | null = null;

/** The whole Turath catalog (names, authors, categories), loaded once. */
function loadCatalog(): Promise<Map<number, CatalogBook>> {
  catalogPromise ??= fetch(CATALOG_URL)
    .then((r) => r.json())
    .then((d) => {
      const out = new Map<number, CatalogBook>();
      for (const b of Object.values(d.books) as Array<Record<string, number | string>>) {
        const a = d.authors[String(b.author_id)];
        const c = d.cats[String(b.cat_id)];
        out.set(Number(b.id), {
          id: Number(b.id),
          title: String(b.name).trim(),
          author: a ? String(a.name).trim() : "",
          category: c ? String(c.name) : "",
          pages: Number(b.page_count ?? 0),
          size: Number(b.size ?? 0),
          hasPdf: b.has_pdf === (true as unknown as number),
        });
      }
      return out;
    })
    .catch((e) => {
      catalogPromise = null;
      throw e;
    });
  return catalogPromise;
}

/** "https://app.turath.io/book/12028", "turath.io/book/12028?page=5" or "12028". */
function turathIdFrom(input: string): number | null {
  const s = input.trim();
  const m = s.match(/book\/(\d+)/) ?? s.match(/^(\d+)$/);
  return m ? Number(m[1]) : null;
}

const norm = (s: string) =>
  s.replace(/[ؐ-ًؚ-ٰٟۖ-ۭـ]/g, "")
    .replace(/[أإآٱ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي");

export default function Books({ notify }: { notify: Notify }) {
  const [list, setList] = useState<Book[] | null>(null);
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<Book | null>(null);
  const [filter, setFilter] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const { data, error } = await supabase.from("books").select("*").order("sort");
    if (error) notify(error.message, false);
    setList((data as Book[]) ?? []);
  }, [notify]);
  useEffect(() => { load(); }, [load]);

  const shown = useMemo(() => {
    if (!list) return null;
    const q = norm(filter.trim());
    return q ? list.filter((b) => norm(`${b.title} ${b.author ?? ""}`).includes(q)) : list;
  }, [list, filter]);

  async function patch(b: Book, p: Partial<Book>, msg: string) {
    const { error } = await supabase.from("books").update(p).eq("id", b.id);
    if (error) return notify(error.message, false);
    notify(msg);
    load();
  }

  async function move(i: number, d: -1 | 1) {
    if (!list || filter) return;
    const j = i + d;
    if (j < 0 || j >= list.length) return;
    const next = [...list];
    [next[i], next[j]] = [next[j], next[i]];
    setList(next);
    setSaving(true);
    const rows = next.map((b, k) => ({ ...b, sort: (k + 1) * 10 }));
    const { error } = await supabase.from("books").upsert(rows, { onConflict: "id" });
    setSaving(false);
    if (error) notify(error.message, false);
  }

  async function remove(b: Book) {
    if (!confirm(`حذف «${b.title}» من المكتبة؟`)) return;
    const { error } = await supabase.from("books").delete().eq("id", b.id);
    if (error) return notify(error.message, false);
    notify("تم الحذف");
    load();
  }

  const featuredCount = list?.filter((b) => b.featured && !b.hidden).length ?? 0;

  return (
    <>
      <PageHeader
        title="الكتب"
        subtitle={list ? `${list.length} كتاباً · ${featuredCount} في «كتب مختارة»` : "مكتبة الكتب الشرعية في التطبيق"}
        action={<button className="btn primary" onClick={() => setAdding(true)}><Icon name="plus" size={18} /> إضافة كتاب</button>}
      />

      <div className="note" style={{ marginBottom: 14 }}>
        <Icon name="book" size={18} />
        <div>
          الكتب المميزة ★ تظهر في «كتب مختارة» بالتطبيق بنفس هذا الترتيب. أي كتاب في مكتبة تراث (أكثر من 8 آلاف كتاب) يظهر
          للمستخدم في البحث وفي «الأقسام» تلقائياً، وأي كتاب جديد يضيفه تراث يظهر وحده. «إخفاء» يمنع الكتاب من الظهور في أي مكان.
        </div>
      </div>

      <div className="card" style={{ padding: 12, marginBottom: 12 }}>
        <div className="search">
          <Icon name="search" size={18} />
          <input placeholder="ابحث في كتب المكتبة…" value={filter} onChange={(e) => setFilter(e.target.value)} />
        </div>
      </div>

      {shown === null ? <Skeleton rows={6} /> : shown.length === 0 ? (
        <div className="card"><Empty icon="book" title="لا توجد كتب" text="أضف كتاباً من تراث أو رابط PDF" /></div>
      ) : (
        <div className="rlist">
          {shown.map((b, i) => (
            <div className="ritem" key={b.id} style={{ opacity: b.hidden ? 0.5 : 1 }}>
              <div className="avatar" style={{ background: b.featured && !b.hidden ? "var(--gold)" : undefined, color: b.featured && !b.hidden ? "var(--emerald-900)" : undefined }}>
                {b.source === "pdf" ? "PDF" : i + 1}
              </div>
              <div className="info">
                <b>{b.title}</b>
                <span>
                  {[b.author, b.category, b.pages ? `${b.pages} صفحة` : null, b.source === "turath" ? `تراث #${b.turath_id}` : "PDF"]
                    .filter(Boolean).join(" · ")}
                  {b.hidden ? " · مخفي" : ""}
                </span>
              </div>
              {!filter && <>
                <button className="btn sm ghost" disabled={i === 0 || saving} onClick={() => move(i, -1)} aria-label="لأعلى">▲</button>
                <button className="btn sm ghost" disabled={i === shown.length - 1 || saving} onClick={() => move(i, 1)} aria-label="لأسفل">▼</button>
              </>}
              <button className={`btn sm ${b.featured ? "gold" : "ghost"}`}
                onClick={() => patch(b, { featured: !b.featured }, b.featured ? "أزيل من الكتب المختارة" : "أضيف للكتب المختارة")}>
                {b.featured ? "★ مختار" : "☆ تمييز"}
              </button>
              <button className="btn sm ghost" title={b.hidden ? "إظهار" : "إخفاء"}
                onClick={() => patch(b, { hidden: !b.hidden }, b.hidden ? "أصبح ظاهراً" : "تم الإخفاء")}>
                <Icon name={b.hidden ? "eye" : "eyeoff"} size={16} />
              </button>
              <button className="btn sm ghost" title="تعديل" onClick={() => setEditing(b)}><Icon name="edit" size={16} /></button>
              <button className="btn sm danger" title="حذف" onClick={() => remove(b)}><Icon name="trash" size={16} /></button>
            </div>
          ))}
        </div>
      )}

      {adding && <AddBook notify={notify} existing={list ?? []} onClose={() => setAdding(false)} onSaved={() => { setAdding(false); load(); }} />}
      {editing && <EditBook book={editing} notify={notify} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); load(); }} />}
    </>
  );
}

function AddBook({ notify, existing, onClose, onSaved }: {
  notify: Notify; existing: Book[]; onClose: () => void; onSaved: () => void;
}) {
  const [mode, setMode] = useState<"turath" | "pdf">("turath");
  const [link, setLink] = useState("");
  const [query, setQuery] = useState("");
  const [catalog, setCatalog] = useState<Map<number, CatalogBook> | null>(null);
  const [catalogError, setCatalogError] = useState(false);
  const [picked, setPicked] = useState<CatalogBook | null>(null);
  const [pdf, setPdf] = useState({ title: "", author: "", category: "", url: "" });
  const [featured, setFeatured] = useState(true);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    loadCatalog().then(setCatalog).catch(() => setCatalogError(true));
  }, []);

  // A pasted link picks the book directly.
  useEffect(() => {
    const id = turathIdFrom(link);
    if (id && catalog) setPicked(catalog.get(id) ?? null);
  }, [link, catalog]);

  const results = useMemo(() => {
    const q = norm(query.trim());
    if (!catalog || q.length < 2) return [];
    const words = q.split(/\s+/);
    const out: CatalogBook[] = [];
    for (const b of catalog.values()) {
      const k = norm(`${b.title} ${b.author}`);
      if (b.hasPdf && words.every((w) => k.includes(w))) out.push(b);
    }
    return out.sort((a, b) => b.size - a.size).slice(0, 30);
  }, [catalog, query]);

  const maxSort = existing.reduce((m, b) => Math.max(m, b.sort), 0);

  async function save() {
    setBusy(true);
    let row: Partial<Book>;
    if (mode === "turath") {
      if (!picked) { setBusy(false); return notify("اختر كتاباً من تراث أولاً", false); }
      if (!picked.hasPdf) { setBusy(false); return notify("هذا الكتاب ليس له نسخة مصورة PDF في تراث، فلا يمكن فتحه في التطبيق", false); }
      if (existing.some((b) => b.turath_id === picked.id)) { setBusy(false); return notify("هذا الكتاب موجود بالفعل", false); }
      row = { source: "turath", turath_id: picked.id, title: picked.title, author: picked.author, category: picked.category, pages: picked.pages };
    } else {
      if (!pdf.title.trim() || !/^https?:\/\//.test(pdf.url.trim())) { setBusy(false); return notify("اكتب اسم الكتاب ورابط PDF صحيحاً", false); }
      row = { source: "pdf", title: pdf.title.trim(), author: pdf.author.trim() || null, category: pdf.category.trim() || null, pdf_url: pdf.url.trim() };
    }
    const { error } = await supabase.from("books").insert({ ...row, featured, sort: maxSort + 10 });
    setBusy(false);
    if (error) return notify(error.message, false);
    notify(`تمت إضافة «${row.title}»`);
    onSaved();
  }

  return (
    <Modal title="إضافة كتاب" onClose={onClose} wide
      footer={<>
        <label style={{ display: "flex", gap: 8, alignItems: "center", marginInlineEnd: "auto" }}>
          <input type="checkbox" checked={featured} onChange={(e) => setFeatured(e.target.checked)} /> يظهر في «كتب مختارة»
        </label>
        <button className="btn ghost" onClick={onClose}>إلغاء</button>
        <button className="btn primary" disabled={busy} onClick={save}>{busy ? "جارٍ الحفظ…" : "إضافة"}</button>
      </>}>
      <div className="seg" style={{ marginBottom: 14 }}>
        <button className={mode === "turath" ? "on" : ""} onClick={() => setMode("turath")}>من مكتبة تراث</button>
        <button className={mode === "pdf" ? "on" : ""} onClick={() => setMode("pdf")}>رابط PDF</button>
      </div>

      {mode === "turath" ? (
        <>
          <Field label="رابط الكتاب في تراث" hint="مثال: https://app.turath.io/book/12028 — يفتح في التطبيق بالنسخة المصورة PDF للطبعة الورقية">
            <input dir="ltr" value={link} onChange={(e) => setLink(e.target.value)} placeholder="https://app.turath.io/book/…" />
          </Field>
          <Field label="أو ابحث بالاسم" hint={catalogError ? "تعذر تحميل فهرس تراث، استخدم الرابط" : catalog ? `${catalog.size} كتاباً في تراث` : "جارٍ تحميل فهرس تراث…"}>
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="مثال: صيد الخاطر" />
          </Field>
          {results.length > 0 && (
            <div className="rlist" style={{ maxHeight: 260, overflow: "auto", marginBottom: 12 }}>
              {results.map((b) => (
                <button key={b.id} className="ritem" style={{ textAlign: "start", width: "100%", border: picked?.id === b.id ? "2px solid var(--emerald-700)" : undefined }}
                  onClick={() => { setPicked(b); setLink(`https://app.turath.io/book/${b.id}`); }}>
                  <div className="info"><b>{b.title}</b><span>{b.author} · {b.category} · {b.pages} صفحة</span></div>
                </button>
              ))}
            </div>
          )}
          {picked ? (
            <div className="note"><Icon name={picked.hasPdf ? "check" : "x"} size={18} /><div><b>{picked.title}</b><br />{picked.author} · {picked.category} · {picked.pages} صفحة{picked.hasPdf ? "" : " — لا توجد نسخة مصورة PDF لهذا الكتاب، اختر طبعة أخرى"}</div></div>
          ) : turathIdFrom(link) && catalog ? (
            <div className="note"><Icon name="x" size={18} /><div>لم يُعثر على هذا الرقم في فهرس تراث</div></div>
          ) : null}
        </>
      ) : (
        <>
          <Field label="اسم الكتاب"><input value={pdf.title} onChange={(e) => setPdf({ ...pdf, title: e.target.value })} /></Field>
          <Field label="المؤلف"><input value={pdf.author} onChange={(e) => setPdf({ ...pdf, author: e.target.value })} /></Field>
          <Field label="التصنيف" hint="اختياري — مثال: السيرة النبوية"><input value={pdf.category} onChange={(e) => setPdf({ ...pdf, category: e.target.value })} /></Field>
          <Field label="رابط PDF" hint="رابط مباشر لملف PDF، يُحمَّل ويُفتح داخل التطبيق">
            <input dir="ltr" value={pdf.url} onChange={(e) => setPdf({ ...pdf, url: e.target.value })} placeholder="https://…/book.pdf" />
          </Field>
        </>
      )}
    </Modal>
  );
}

function EditBook({ book, notify, onClose, onSaved }: { book: Book; notify: Notify; onClose: () => void; onSaved: () => void }) {
  const [f, setF] = useState({ title: book.title, author: book.author ?? "", category: book.category ?? "", pdf_url: book.pdf_url ?? "" });
  const [busy, setBusy] = useState(false);

  async function save() {
    if (!f.title.trim()) return notify("اكتب اسم الكتاب", false);
    setBusy(true);
    const p: Partial<Book> = { title: f.title.trim(), author: f.author.trim() || null, category: f.category.trim() || null };
    if (book.source === "pdf") p.pdf_url = f.pdf_url.trim();
    const { error } = await supabase.from("books").update(p).eq("id", book.id);
    setBusy(false);
    if (error) return notify(error.message, false);
    notify("تم الحفظ");
    onSaved();
  }

  return (
    <Modal title="تعديل الكتاب" onClose={onClose}
      footer={<><button className="btn ghost" onClick={onClose}>إلغاء</button><button className="btn primary" disabled={busy} onClick={save}>حفظ</button></>}>
      <Field label="اسم الكتاب" hint="يظهر على الغلاف؛ ما بعد « - » يظهر كطبعة صغيرة"><input value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} /></Field>
      <Field label="المؤلف"><input value={f.author} onChange={(e) => setF({ ...f, author: e.target.value })} /></Field>
      <Field label="التصنيف"><input value={f.category} onChange={(e) => setF({ ...f, category: e.target.value })} /></Field>
      {book.source === "pdf" && (
        <Field label="رابط PDF"><input dir="ltr" value={f.pdf_url} onChange={(e) => setF({ ...f, pdf_url: e.target.value })} /></Field>
      )}
    </Modal>
  );
}
