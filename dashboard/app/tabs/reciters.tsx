"use client";

import { useEffect, useState } from "react";
import { Recitation, Reciter, supabase } from "@/lib/supabase";

export default function Reciters() {
  const [rows, setRows] = useState<Reciter[]>([]);
  const [open, setOpen] = useState<Reciter | null>(null);
  const [name, setName] = useState("");
  const [group, setGroup] = useState("قراء الحوامدية");
  const [msg, setMsg] = useState("");

  async function load() {
    const { data } = await supabase.from("reciters").select("*").order("sort").order("name");
    setRows((data as Reciter[]) ?? []);
  }
  useEffect(() => {
    load();
  }, []);

  async function add() {
    if (!name.trim()) return;
    const { error } = await supabase
      .from("reciters")
      .insert({ name: name.trim(), group_name: group.trim() || null, is_published: false });
    setMsg(error ? error.message : "تمت إضافة القارئ (مخفي حتى ترفع تلاواته وتنشره)");
    setName("");
    load();
  }

  async function toggle(r: Reciter) {
    await supabase.from("reciters").update({ is_published: !r.is_published }).eq("id", r.id);
    load();
  }

  async function remove(r: Reciter) {
    if (!confirm(`حذف ${r.name} وكل تلاواته؟`)) return;
    const { data: files } = await supabase.storage.from("media").list(`reciters/${r.id}`);
    if (files?.length) {
      await supabase.storage.from("media").remove(files.map((f) => `reciters/${r.id}/${f.name}`));
    }
    await supabase.from("reciters").delete().eq("id", r.id);
    if (open?.id === r.id) setOpen(null);
    load();
  }

  return (
    <>
      <div className="card">
        <h3 style={{ marginTop: 0 }}>إضافة قارئ</h3>
        <div className="row">
          <input placeholder="اسم القارئ" value={name} onChange={(e) => setName(e.target.value)} />
          <input placeholder="المجموعة (مثل: قراء الحوامدية)" value={group}
            onChange={(e) => setGroup(e.target.value)} />
          <button className="fit gold" onClick={add}>إضافة</button>
        </div>
        {msg && <div className="msg ok">{msg}</div>}
      </div>

      <div className="card">
        <table>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td><b>{r.name}</b><div className="muted">{r.group_name ?? ""} • {r.riwaya}</div></td>
                <td><span className={`pill ${r.is_published ? "" : "pending"}`}>{r.is_published ? "منشور" : "مخفي"}</span></td>
                <td style={{ whiteSpace: "nowrap" }}>
                  <button className="small" onClick={() => setOpen(r)}>التلاوات</button>{" "}
                  <button className="small ghost" onClick={() => toggle(r)}>{r.is_published ? "إخفاء" : "نشر"}</button>{" "}
                  <button className="small danger" onClick={() => remove(r)}>حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {rows.length === 0 && <p className="center muted">لا يوجد قراء مضافون بعد</p>}
      </div>

      {open && <Recitations reciter={open} />}
    </>
  );
}

function Recitations({ reciter }: { reciter: Reciter }) {
  const [rows, setRows] = useState<Recitation[]>([]);
  const [surah, setSurah] = useState(1);
  const [busy, setBusy] = useState("");

  async function load() {
    const { data } = await supabase
      .from("recitations")
      .select("*")
      .eq("reciter_id", reciter.id)
      .order("surah");
    setRows((data as Recitation[]) ?? []);
  }
  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reciter.id]);

  // Files named like 001.mp3 / 18.mp3 are matched to their surah automatically.
  async function upload(files: FileList | null) {
    if (!files?.length) return;
    for (const f of Array.from(files)) {
      const m = f.name.match(/(\d{1,3})/);
      const s = files.length === 1 ? surah : m ? Number(m[1]) : NaN;
      if (!(s >= 1 && s <= 114)) {
        setBusy(`تخطي ${f.name}: لم أعرف رقم السورة`);
        continue;
      }
      setBusy(`رفع سورة ${s}...`);
      const path = `reciters/${reciter.id}/${String(s).padStart(3, "0")}.mp3`;
      const { error } = await supabase.storage
        .from("media")
        .upload(path, f, { upsert: true, contentType: "audio/mpeg" });
      if (error) {
        setBusy(`خطأ في ${f.name}: ${error.message}`);
        continue;
      }
      const url = supabase.storage.from("media").getPublicUrl(path).data.publicUrl;
      await supabase.from("recitations").upsert(
        { reciter_id: reciter.id, surah: s, url },
        { onConflict: "reciter_id,surah" },
      );
    }
    setBusy("تم الرفع");
    load();
  }

  async function remove(r: Recitation) {
    await supabase.storage
      .from("media")
      .remove([`reciters/${reciter.id}/${String(r.surah).padStart(3, "0")}.mp3`]);
    await supabase.from("recitations").delete().eq("id", r.id);
    load();
  }

  return (
    <div className="card" style={{ borderColor: "var(--gold)" }}>
      <h3 style={{ marginTop: 0 }}>تلاوات {reciter.name} ({rows.length} / 114)</h3>
      <p className="muted">
        ارفع ملف سورة واحدة مع اختيار رقمها، أو عدة ملفات مرة واحدة بأسماء مثل 001.mp3 و 018.mp3.
      </p>
      <div className="row">
        <input type="number" min={1} max={114} value={surah}
          onChange={(e) => setSurah(Number(e.target.value))} />
        <input type="file" accept="audio/mpeg,audio/mp3" multiple
          onChange={(e) => upload(e.target.files)} />
      </div>
      {busy && <div className="msg ok">{busy}</div>}
      <table>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id}>
              <td>سورة رقم {r.surah}</td>
              <td><audio controls preload="none" src={r.url} style={{ height: 32 }} /></td>
              <td><button className="small danger" onClick={() => remove(r)}>حذف</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
