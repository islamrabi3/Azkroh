"use client";

import { useCallback, useEffect, useState } from "react";
import { ContentItem, supabase } from "@/lib/supabase";
import { Empty, Field, Icon, Modal, PageHeader, Skeleton } from "@/lib/ui";
import type { Notify } from "../page";

const KINDS: Record<string, { label: string; icon: string }> = {
  video: { label: "فيديو", icon: "play" },
  playlist: { label: "قائمة تشغيل", icon: "play" },
  link: { label: "رابط", icon: "link" },
  article: { label: "مقال", icon: "book" },
  pdf: { label: "ملف PDF", icon: "file" },
  audio: { label: "صوت", icon: "mic" },
};
const SECTIONS: Record<string, string> = { home: "الصفحة الرئيسية", learning: "مواد تعليمية" };

function ytThumb(url: string): string | null {
  const m = url.match(/(?:youtu\.be\/|v=|shorts\/|embed\/)([\w-]{11})/);
  return m ? `https://i.ytimg.com/vi/${m[1]}/hqdefault.jpg` : null;
}

const blank = (): Partial<ContentItem> => ({
  kind: "video", section: "home", title: "", description: "", url: "",
  thumbnail_url: "", sort: 0, is_published: true,
});

export default function Content({ notify }: { notify: Notify }) {
  const [rows, setRows] = useState<ContentItem[] | null>(null);
  const [editing, setEditing] = useState<Partial<ContentItem> | null>(null);

  const load = useCallback(async () => {
    const { data, error } = await supabase.from("content_items").select("*").order("sort").order("created_at", { ascending: false });
    if (error) notify(error.message, false);
    setRows((data as ContentItem[]) ?? []);
  }, [notify]);
  useEffect(() => { load(); }, [load]);

  async function save() {
    if (!editing?.title?.trim() || !editing.url?.trim()) {
      notify("العنوان والرابط مطلوبان", false);
      return;
    }
    const row = {
      kind: editing.kind, section: editing.section, title: editing.title.trim(),
      description: editing.description ?? "", url: editing.url.trim(),
      thumbnail_url: editing.thumbnail_url?.trim() || ytThumb(editing.url) || null,
      sort: Number(editing.sort) || 0, is_published: !!editing.is_published,
    };
    const { error } = editing.id
      ? await supabase.from("content_items").update(row).eq("id", editing.id)
      : await supabase.from("content_items").insert(row);
    notify(error ? error.message : "تم الحفظ", !error);
    if (!error) { setEditing(null); load(); }
  }

  async function toggle(r: ContentItem) {
    await supabase.from("content_items").update({ is_published: !r.is_published }).eq("id", r.id);
    notify(r.is_published ? "تم الإخفاء من التطبيق" : "تم النشر في التطبيق");
    load();
  }

  async function remove(r: ContentItem) {
    if (!confirm(`حذف «${r.title}»؟`)) return;
    await supabase.from("content_items").delete().eq("id", r.id);
    notify("تم الحذف");
    load();
  }

  const preview = editing ? editing.thumbnail_url || (editing.url ? ytThumb(editing.url) : null) : null;

  return (
    <>
      <PageHeader title="الفيديوهات والروابط" subtitle="محتوى يظهر للمستخدمين في الصفحة الرئيسية تحت «مختارات لك»."
        action={<button className="btn gold" onClick={() => setEditing(blank())}><Icon name="plus" size={18} /> إضافة محتوى</button>} />

      {rows === null ? <Skeleton rows={2} /> : rows.length === 0 ? (
        <div className="card"><Empty icon="play" title="لا يوجد محتوى بعد"
          text="أضف فيديو يوتيوب أو رابطاً ليظهر في التطبيق"
          action={<button className="btn" onClick={() => setEditing(blank())}><Icon name="plus" size={18} /> إضافة أول عنصر</button>} /></div>
      ) : (
        <div className="cgrid">
          {rows.map((r) => {
            const t = r.thumbnail_url || ytThumb(r.url);
            return (
              <div className="ccard" key={r.id}>
                <div className="thumb">
                  {t ? <img src={t} alt="" /> : <Icon name={KINDS[r.kind]?.icon ?? "link"} size={34} />}
                </div>
                <div className="body">
                  <div className="q-meta" style={{ marginBottom: 6 }}>
                    <span className="badge-s neutral">{KINDS[r.kind]?.label}</span>
                    <span className={`badge-s ${r.is_published ? "" : "off"}`}>{r.is_published ? "منشور" : "مخفي"}</span>
                  </div>
                  <h4>{r.title}</h4>
                  <a href={r.url} target="_blank" rel="noreferrer" style={{ fontSize: 12.5 }} dir="ltr">{r.url.replace(/^https?:\/\//, "").slice(0, 40)}</a>
                </div>
                <div className="foot">
                  <button className="btn sm ghost" onClick={() => toggle(r)}><Icon name={r.is_published ? "eyeoff" : "eye"} size={16} /> {r.is_published ? "إخفاء" : "نشر"}</button>
                  <button className="btn sm ghost" onClick={() => setEditing(r)}><Icon name="edit" size={16} /></button>
                  <button className="btn sm danger" onClick={() => remove(r)}><Icon name="trash" size={16} /></button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {editing && (
        <Modal title={editing.id ? "تعديل المحتوى" : "إضافة محتوى"} onClose={() => setEditing(null)}
          footer={<>
            <button className="btn ghost" onClick={() => setEditing(null)}>إلغاء</button>
            <button className="btn" onClick={save}>حفظ</button>
          </>}>
          <div className="stack">
            <Field label="الرابط" hint="رابط يوتيوب أو أي صفحة أو ملف. صورة فيديوهات يوتيوب تُضاف تلقائياً.">
              <input dir="ltr" value={editing.url} placeholder="https://youtube.com/watch?v=..."
                onChange={(e) => setEditing({ ...editing, url: e.target.value })} />
            </Field>
            {preview && <img src={preview} alt="" style={{ width: "100%", maxHeight: 220, objectFit: "cover", borderRadius: 12 }} />}
            <Field label="العنوان">
              <input value={editing.title} onChange={(e) => setEditing({ ...editing, title: e.target.value })} />
            </Field>
            <div className="grid-3">
              <Field label="النوع">
                <select value={editing.kind} onChange={(e) => setEditing({ ...editing, kind: e.target.value as ContentItem["kind"] })}>
                  {Object.entries(KINDS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
                </select>
              </Field>
              <Field label="القسم">
                <select value={editing.section} onChange={(e) => setEditing({ ...editing, section: e.target.value })}>
                  {Object.entries(SECTIONS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
              </Field>
              <Field label="الترتيب">
                <input type="number" value={editing.sort ?? 0} onChange={(e) => setEditing({ ...editing, sort: Number(e.target.value) })} />
              </Field>
            </div>
            <Field label="وصف قصير (اختياري)">
              <textarea value={editing.description ?? ""} onChange={(e) => setEditing({ ...editing, description: e.target.value })} />
            </Field>
            <Field label="صورة مصغرة (اختياري)">
              <input dir="ltr" value={editing.thumbnail_url ?? ""} onChange={(e) => setEditing({ ...editing, thumbnail_url: e.target.value })} />
            </Field>
            <label className="row" style={{ gap: 8, cursor: "pointer" }}>
              <input type="checkbox" checked={!!editing.is_published}
                onChange={(e) => setEditing({ ...editing, is_published: e.target.checked })} />
              منشور في التطبيق
            </label>
          </div>
        </Modal>
      )}
    </>
  );
}
