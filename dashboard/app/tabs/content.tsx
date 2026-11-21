"use client";

import { useEffect, useState } from "react";
import { ContentItem, supabase } from "@/lib/supabase";

const KINDS: Record<string, string> = {
  video: "فيديو",
  playlist: "قائمة تشغيل",
  link: "رابط",
  article: "مقال",
  pdf: "ملف PDF",
  audio: "صوت",
};
const SECTIONS: Record<string, string> = {
  home: "الصفحة الرئيسية",
  learning: "مواد تعليمية",
};

function youtubeThumb(url: string): string | null {
  const m = url.match(/(?:youtu\.be\/|v=|shorts\/|embed\/)([\w-]{11})/);
  return m ? `https://i.ytimg.com/vi/${m[1]}/hqdefault.jpg` : null;
}

const blank = (): Partial<ContentItem> => ({
  kind: "video",
  section: "home",
  title: "",
  description: "",
  url: "",
  thumbnail_url: "",
  sort: 0,
  is_published: true,
});

export default function Content() {
  const [rows, setRows] = useState<ContentItem[]>([]);
  const [editing, setEditing] = useState<Partial<ContentItem> | null>(null);
  const [msg, setMsg] = useState("");

  async function load() {
    const { data, error } = await supabase
      .from("content_items")
      .select("*")
      .order("section")
      .order("sort");
    if (error) setMsg(error.message);
    setRows((data as ContentItem[]) ?? []);
  }
  useEffect(() => {
    load();
  }, []);

  async function save() {
    if (!editing?.title?.trim() || !editing.url?.trim()) {
      setMsg("العنوان والرابط مطلوبان");
      return;
    }
    const row = {
      kind: editing.kind,
      section: editing.section,
      title: editing.title.trim(),
      description: editing.description ?? "",
      url: editing.url.trim(),
      thumbnail_url: editing.thumbnail_url?.trim() || youtubeThumb(editing.url) || null,
      sort: Number(editing.sort) || 0,
      is_published: !!editing.is_published,
    };
    const { error } = editing.id
      ? await supabase.from("content_items").update(row).eq("id", editing.id)
      : await supabase.from("content_items").insert(row);
    setMsg(error ? error.message : "تم الحفظ");
    if (!error) setEditing(null);
    load();
  }

  async function toggle(r: ContentItem) {
    await supabase.from("content_items").update({ is_published: !r.is_published }).eq("id", r.id);
    load();
  }

  async function remove(id: string) {
    if (!confirm("حذف هذا العنصر؟")) return;
    await supabase.from("content_items").delete().eq("id", id);
    load();
  }

  return (
    <>
      <div className="card">
        <div className="row">
          <p className="muted" style={{ margin: 0 }}>
            فيديوهات يوتيوب وروابط ومواد تعليمية تظهر في الصفحة الرئيسية للتطبيق.
          </p>
          <button className="fit gold" onClick={() => setEditing(blank())}>+ إضافة</button>
        </div>
        {msg && <div className="msg ok">{msg}</div>}
      </div>

      {editing && (
        <div className="card" style={{ borderColor: "var(--gold)" }}>
          <div className="row">
            <div>
              <label>النوع</label>
              <select value={editing.kind}
                onChange={(e) => setEditing({ ...editing, kind: e.target.value as ContentItem["kind"] })}>
                {Object.entries(KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
            </div>
            <div>
              <label>القسم</label>
              <select value={editing.section}
                onChange={(e) => setEditing({ ...editing, section: e.target.value })}>
                {Object.entries(SECTIONS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
            </div>
            <div>
              <label>الترتيب</label>
              <input type="number" value={editing.sort ?? 0}
                onChange={(e) => setEditing({ ...editing, sort: Number(e.target.value) })} />
            </div>
          </div>
          <label>العنوان</label>
          <input value={editing.title} onChange={(e) => setEditing({ ...editing, title: e.target.value })} />
          <label>الرابط (يوتيوب أو أي رابط)</label>
          <input dir="ltr" value={editing.url} onChange={(e) => setEditing({ ...editing, url: e.target.value })} />
          <label>وصف قصير (اختياري)</label>
          <textarea value={editing.description ?? ""}
            onChange={(e) => setEditing({ ...editing, description: e.target.value })} />
          <label>صورة مصغرة (اختياري — تُستخرج تلقائياً لفيديوهات يوتيوب)</label>
          <input dir="ltr" value={editing.thumbnail_url ?? ""}
            onChange={(e) => setEditing({ ...editing, thumbnail_url: e.target.value })} />
          <label>
            <input type="checkbox" style={{ width: "auto" }} checked={!!editing.is_published}
              onChange={(e) => setEditing({ ...editing, is_published: e.target.checked })} /> منشور في التطبيق
          </label>
          <div className="row" style={{ marginTop: 12 }}>
            <button className="fit" onClick={save}>حفظ</button>
            <button className="fit ghost" onClick={() => setEditing(null)}>إلغاء</button>
          </div>
        </div>
      )}

      <div className="card">
        <table>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td style={{ width: 110 }}>
                  {(r.thumbnail_url || youtubeThumb(r.url)) && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img className="thumb" alt="" src={r.thumbnail_url || youtubeThumb(r.url)!} />
                  )}
                </td>
                <td>
                  <b>{r.title}</b>
                  <div className="muted">{KINDS[r.kind]} • {SECTIONS[r.section] ?? r.section}</div>
                </td>
                <td><span className={`pill ${r.is_published ? "" : "pending"}`}>{r.is_published ? "منشور" : "مخفي"}</span></td>
                <td style={{ whiteSpace: "nowrap" }}>
                  <button className="small ghost" onClick={() => toggle(r)}>{r.is_published ? "إخفاء" : "نشر"}</button>{" "}
                  <button className="small ghost" onClick={() => setEditing(r)}>تعديل</button>{" "}
                  <button className="small danger" onClick={() => remove(r.id)}>حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {rows.length === 0 && <p className="center muted">لا يوجد محتوى بعد</p>}
      </div>
    </>
  );
}
