"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Recitation, Reciter, supabase } from "@/lib/supabase";
import { Empty, Field, Icon, Modal, PageHeader, Skeleton } from "@/lib/ui";
import type { Notify } from "../page";

type ReciterRow = Reciter & { recitations: { count: number }[] };

export default function Reciters({ notify }: { notify: Notify }) {
  const [rows, setRows] = useState<ReciterRow[] | null>(null);
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState("");
  const [group, setGroup] = useState("قراء الحوامدية");
  const [riwaya, setRiwaya] = useState("حفص عن عاصم");
  const [open, setOpen] = useState<Reciter | null>(null);

  const load = useCallback(async () => {
    const { data, error } = await supabase.from("reciters").select("*, recitations(count)").order("sort").order("name");
    if (error) notify(error.message, false);
    setRows((data as ReciterRow[]) ?? []);
  }, [notify]);
  useEffect(() => { load(); }, [load]);

  async function add() {
    if (!name.trim()) return notify("اكتب اسم القارئ", false);
    const { data, error } = await supabase.from("reciters")
      .insert({ name: name.trim(), group_name: group.trim() || null, riwaya: riwaya.trim() || "حفص عن عاصم", is_published: false })
      .select().single();
    if (error) return notify(error.message, false);
    notify("تمت الإضافة، ارفع التلاوات ثم انشره");
    setAdding(false);
    setName("");
    load();
    setOpen(data as Reciter);
  }

  async function toggle(r: Reciter) {
    await supabase.from("reciters").update({ is_published: !r.is_published }).eq("id", r.id);
    notify(r.is_published ? "تم إخفاؤه من التطبيق" : "تم نشره في التطبيق");
    load();
  }

  async function remove(r: Reciter) {
    if (!confirm(`حذف ${r.name} وكل تلاواته؟`)) return;
    const { data: files } = await supabase.storage.from("media").list(`reciters/${r.id}`, { limit: 200 });
    if (files?.length) await supabase.storage.from("media").remove(files.map((f) => `reciters/${r.id}/${f.name}`));
    await supabase.from("reciters").delete().eq("id", r.id);
    notify("تم الحذف");
    load();
  }

  return (
    <>
      <PageHeader title="القراء والتلاوات" subtitle="أضف قراء (مثل قراء الحوامدية) وارفع تلاواتهم لتظهر في قسم الاستماع."
        action={<button className="btn gold" onClick={() => setAdding(true)}><Icon name="plus" size={18} /> قارئ جديد</button>} />

      {rows === null ? <Skeleton rows={3} /> : rows.length === 0 ? (
        <div className="card"><Empty icon="mic" title="لا يوجد قراء مضافون بعد"
          text="أضف قارئاً ثم ارفع ملفات السور الصوتية"
          action={<button className="btn" onClick={() => setAdding(true)}><Icon name="plus" size={18} /> إضافة قارئ</button>} /></div>
      ) : (
        <div className="rlist">
          {rows.map((r) => {
            const n = r.recitations?.[0]?.count ?? 0;
            return (
              <div className="ritem" key={r.id}>
                <div className="avatar">{r.name.charAt(0)}</div>
                <div className="info">
                  <b>{r.name}</b>
                  <span>{r.group_name ?? ""}{r.group_name ? " • " : ""}{r.riwaya}</span>
                </div>
                <div style={{ textAlign: "center" }}>
                  <div className="progress-mini"><i style={{ width: `${(n / 114) * 100}%` }} /></div>
                  <span style={{ fontSize: 12, color: "var(--muted)" }}>{n} / 114 سورة</span>
                </div>
                <span className={`badge-s ${r.is_published ? "" : "off"}`}>{r.is_published ? "منشور" : "مخفي"}</span>
                <button className="btn sm" onClick={() => setOpen(r)}><Icon name="upload" size={16} /> التلاوات</button>
                <button className="btn sm ghost" onClick={() => toggle(r)}><Icon name={r.is_published ? "eyeoff" : "eye"} size={16} /></button>
                <button className="btn sm danger" onClick={() => remove(r)}><Icon name="trash" size={16} /></button>
              </div>
            );
          })}
        </div>
      )}

      {adding && (
        <Modal title="قارئ جديد" onClose={() => setAdding(false)}
          footer={<><button className="btn ghost" onClick={() => setAdding(false)}>إلغاء</button><button className="btn" onClick={add}>إضافة</button></>}>
          <div className="stack">
            <Field label="اسم القارئ"><input value={name} onChange={(e) => setName(e.target.value)} placeholder="مثال: الشيخ محمد جمعة" /></Field>
            <div className="grid-2">
              <Field label="المجموعة"><input value={group} onChange={(e) => setGroup(e.target.value)} /></Field>
              <Field label="الرواية"><input value={riwaya} onChange={(e) => setRiwaya(e.target.value)} /></Field>
            </div>
          </div>
        </Modal>
      )}

      {open && <Recitations reciter={open} notify={notify} onClose={() => { setOpen(null); load(); }} />}
    </>
  );
}

function Recitations({ reciter, notify, onClose }: { reciter: Reciter; notify: Notify; onClose: () => void }) {
  const [rows, setRows] = useState<Recitation[]>([]);
  const [surah, setSurah] = useState(1);
  const [busy, setBusy] = useState("");
  const [over, setOver] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    const { data } = await supabase.from("recitations").select("*").eq("reciter_id", reciter.id).order("surah");
    setRows((data as Recitation[]) ?? []);
  }, [reciter.id]);
  useEffect(() => { load(); }, [load]);

  const has = new Map(rows.map((r) => [r.surah, r]));
  const current = has.get(surah);

  // One file goes to the selected surah; several files are matched by the
  // number in their names (001.mp3, 18.mp3 ...).
  async function upload(files: FileList | null) {
    if (!files?.length) return;
    let ok = 0;
    for (const f of Array.from(files)) {
      const m = f.name.match(/(\d{1,3})/);
      const s = files.length === 1 ? surah : m ? Number(m[1]) : NaN;
      if (!(s >= 1 && s <= 114)) { notify(`لم أعرف رقم السورة في ${f.name}`, false); continue; }
      setBusy(`جاري رفع سورة ${s}... (${ok + 1} من ${files.length})`);
      const path = `reciters/${reciter.id}/${String(s).padStart(3, "0")}.mp3`;
      const { error } = await supabase.storage.from("media").upload(path, f, { upsert: true, contentType: "audio/mpeg" });
      if (error) { notify(`${f.name}: ${error.message}`, false); continue; }
      const url = supabase.storage.from("media").getPublicUrl(path).data.publicUrl;
      await supabase.from("recitations").upsert({ reciter_id: reciter.id, surah: s, url }, { onConflict: "reciter_id,surah" });
      ok++;
    }
    setBusy("");
    notify(`تم رفع ${ok} ملف`);
    load();
  }

  async function removeCurrent() {
    if (!current) return;
    await supabase.storage.from("media").remove([`reciters/${reciter.id}/${String(surah).padStart(3, "0")}.mp3`]);
    await supabase.from("recitations").delete().eq("id", current.id);
    notify("تم حذف التلاوة");
    load();
  }

  return (
    <Modal title={`تلاوات ${reciter.name} — ${rows.length} / 114`} onClose={onClose} wide>
      <div className="stack">
        <div
          className={`drop ${over ? "over" : ""}`}
          onClick={() => input.current?.click()}
          onDragOver={(e) => { e.preventDefault(); setOver(true); }}
          onDragLeave={() => setOver(false)}
          onDrop={(e) => { e.preventDefault(); setOver(false); upload(e.dataTransfer.files); }}
        >
          <input ref={input} type="file" accept="audio/mpeg,audio/mp3" multiple onChange={(e) => upload(e.target.files)} />
          <div style={{ color: "var(--emerald-700)", marginBottom: 6 }}><Icon name="upload" size={28} /></div>
          {busy || <>اسحب ملفات MP3 هنا أو اضغط للاختيار<br />
            <small style={{ color: "var(--muted)" }}>ملف واحد ← يُرفع للسورة المحددة ({surah}). عدة ملفات ← حسب الرقم في الاسم مثل 001.mp3</small></>}
        </div>

        <div className="surah-grid">
          {Array.from({ length: 114 }, (_, i) => i + 1).map((n) => (
            <button key={n} className={`${has.has(n) ? "has" : ""} ${n === surah ? "cur" : ""}`} onClick={() => setSurah(n)}>{n}</button>
          ))}
        </div>

        <div className="card" style={{ background: "#fbfaf6" }}>
          <div className="row">
            <b>سورة رقم {surah}</b>
            <span className={`badge-s ${current ? "" : "off"}`}>{current ? "مرفوعة" : "غير مرفوعة"}</span>
            <span className="spacer" />
            {current && <button className="btn sm danger" onClick={removeCurrent}><Icon name="trash" size={16} /> حذف</button>}
          </div>
          {current && <audio controls preload="none" src={current.url} style={{ width: "100%", marginTop: 10 }} />}
        </div>
      </div>
    </Modal>
  );
}
