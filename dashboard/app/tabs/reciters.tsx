"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Recitation, Reciter, supabase } from "@/lib/supabase";
import { Empty, Field, Icon, Modal, PageHeader, Skeleton } from "@/lib/ui";
import type { Notify } from "../page";

type ReciterRow = Reciter & {
  server_url: string | null;
  recitations: { count: number }[];
};
type Override = { key: string; name: string | null; hidden: boolean; featured: boolean; sort: number };
type AppReciter = { key: string; name: string; sub: string };

/** Reciters built into the app (besides the mp3quran library). */
const BUILTIN: AppReciter[] = [
  { key: "builtin:hosni_omar", name: "محمد حسني عمر", sub: "حفص عن عاصم - مرتل" },
];

export default function Reciters({ notify }: { notify: Notify }) {
  const [view, setView] = useState<"order" | "app" | "mine">("order");
  return (
    <>
      <PageHeader
        title="القراء"
        subtitle="تحكم في قراء قسم الاستماع: أخفِ أو ميّز أي قارئ، أو أضف قراء جدداً. التغييرات تصل للتطبيق مباشرة دون تحديث."
      />
      <div className="seg" style={{ marginBottom: 16 }}>
        <button className={view === "order" ? "on" : ""} onClick={() => setView("order")}>ترتيب المشهورين</button>
        <button className={view === "app" ? "on" : ""} onClick={() => setView("app")}>قراء التطبيق</button>
        <button className={view === "mine" ? "on" : ""} onClick={() => setView("mine")}>قراء أضفتهم</button>
      </div>
      {view === "order" && <FeaturedOrder notify={notify} />}
      {view === "app" && <AppReciters notify={notify} />}
      {view === "mine" && <MyReciters notify={notify} />}
    </>
  );
}

// ---------------------------------------------------------------------------
// Built-in reciters: hide / feature
// ---------------------------------------------------------------------------
function AppReciters({ notify }: { notify: Notify }) {
  const [all, setAll] = useState<AppReciter[] | null>(null);
  const [ov, setOv] = useState<Record<string, Override>>({});
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState<"all" | "featured" | "hidden">("all");
  const [limit, setLimit] = useState(40);

  useEffect(() => {
    (async () => {
      const { data } = await supabase.from("reciter_overrides").select("key,name,hidden,featured,sort");
      setOv(Object.fromEntries(((data as Override[]) ?? []).map((o) => [o.key, o])));
      try {
        const res = await fetch("https://www.mp3quran.net/api/v3/reciters?language=ar");
        const json = await res.json();
        const list: AppReciter[] = (json.reciters as Array<{ id: number; name: string; moshaf: Array<{ name: string }> }>)
          .map((r) => ({
            key: `mp3quran:${r.id}`,
            name: r.name.trim(),
            sub: r.moshaf.length === 1 ? r.moshaf[0].name : `${r.moshaf.length} روايات`,
          }))
          .sort((a, b) => a.name.localeCompare(b.name, "ar"));
        setAll([...BUILTIN, ...list]);
      } catch {
        setAll(BUILTIN);
        notify("تعذر تحميل قائمة القراء من mp3quran", false);
      }
    })();
  }, [notify]);

  const norm = (s: string) => s.replace(/[ً-ْٰ]/g, "").replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي");

  const shown = useMemo(() => {
    if (!all) return [];
    const nq = norm(q.trim());
    return all.filter((r) => {
      const o = ov[r.key];
      if (filter === "featured" && !o?.featured) return false;
      if (filter === "hidden" && !o?.hidden) return false;
      return !nq || norm(r.name).includes(nq);
    });
  }, [all, ov, q, filter]);

  async function set(r: AppReciter, patch: Partial<Override>) {
    const cur = ov[r.key] ?? { key: r.key, name: r.name, hidden: false, featured: false, sort: 0 };
    const next = { ...cur, ...patch, name: r.name };
    if (patch.featured && !cur.featured) {
      next.sort = Math.max(0, ...Object.values(ov).map((o) => o.sort ?? 0)) + 10;
    }
    setOv({ ...ov, [r.key]: next });
    const { error } = await supabase.from("reciter_overrides").upsert(next, { onConflict: "key" });
    if (error) notify(error.message, false);
    else notify(patch.hidden !== undefined
      ? (patch.hidden ? `تم إخفاء ${r.name}` : `تم إظهار ${r.name}`)
      : (patch.featured ? `${r.name} الآن في «قراء مشهورون»` : `تمت إزالة التمييز`));
  }

  const counts = {
    featured: Object.values(ov).filter((o) => o.featured).length,
    hidden: Object.values(ov).filter((o) => o.hidden).length,
  };

  return (
    <>
      <div className="card" style={{ marginBottom: 14 }}>
        <div className="row">
          <div className="search">
            <Icon name="search" size={18} />
            <input placeholder="ابحث عن قارئ" value={q} onChange={(e) => { setQ(e.target.value); setLimit(40); }} />
          </div>
          <div className="seg">
            <button className={filter === "all" ? "on" : ""} onClick={() => setFilter("all")}>الكل <span className="n">{all?.length ?? "…"}</span></button>
            <button className={filter === "featured" ? "on" : ""} onClick={() => setFilter("featured")}>مميز <span className="n">{counts.featured}</span></button>
            <button className={filter === "hidden" ? "on" : ""} onClick={() => setFilter("hidden")}>مخفي <span className="n">{counts.hidden}</span></button>
          </div>
        </div>
        <div className="note" style={{ marginTop: 12 }}>
          <Icon name="sparkle" size={18} />
          <div>⭐ «تمييز» يضع القارئ أول صف «قراء مشهورون» في التطبيق. «إخفاء» يزيله من قسم الاستماع تماماً.</div>
        </div>
      </div>

      {all === null ? <Skeleton rows={4} /> : shown.length === 0 ? (
        <div className="card"><Empty icon="mic" title="لا توجد نتائج" /></div>
      ) : (
        <div className="rlist">
          {shown.slice(0, limit).map((r) => {
            const o = ov[r.key];
            return (
              <div className="ritem" key={r.key} style={{ opacity: o?.hidden ? 0.6 : 1 }}>
                <div className="avatar">{r.name.charAt(0)}</div>
                <div className="info">
                  <b>{r.name} {o?.featured && <span style={{ color: "var(--gold)" }}>★</span>}</b>
                  <span>{r.sub}</span>
                </div>
                {o?.hidden && <span className="badge-s off">مخفي</span>}
                <button className={`btn sm ${o?.featured ? "gold" : "ghost"}`} disabled={!!o?.hidden}
                  onClick={() => set(r, { featured: !o?.featured })}>
                  ★ {o?.featured ? "مميز" : "تمييز"}
                </button>
                <button className="btn sm ghost" onClick={() => set(r, { hidden: !o?.hidden, featured: false })}>
                  <Icon name={o?.hidden ? "eye" : "eyeoff"} size={16} /> {o?.hidden ? "إظهار" : "إخفاء"}
                </button>
              </div>
            );
          })}
          {shown.length > limit && (
            <button className="btn ghost" onClick={() => setLimit(limit + 40)}>عرض المزيد ({shown.length - limit})</button>
          )}
        </div>
      )}
    </>
  );
}

// ---------------------------------------------------------------------------
// Reciters added from the dashboard (upload files or a link)
// ---------------------------------------------------------------------------
function MyReciters({ notify }: { notify: Notify }) {
  const [rows, setRows] = useState<ReciterRow[] | null>(null);
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState("");
  const [riwaya, setRiwaya] = useState("حفص عن عاصم - مرتل");
  const [mode, setMode] = useState<"upload" | "link">("upload");
  const [link, setLink] = useState("");
  const [open, setOpen] = useState<ReciterRow | null>(null);

  const load = useCallback(async () => {
    const { data, error } = await supabase.from("reciters").select("*, recitations(count)").order("sort").order("name");
    if (error) notify(error.message, false);
    setRows((data as ReciterRow[]) ?? []);
  }, [notify]);
  useEffect(() => { load(); }, [load]);

  const [scan, setScan] = useState("");

  /** Page link (way2quran) -> audio folder; folder links are kept as-is. */
  function toFolder(raw: string): string {
    const u = raw.trim();
    const m = u.match(/way2quran\.com\/(?:[a-z]{2}\/)?reciters\/([\w-]+)/i);
    if (m) return `https://media.way2quran.com/${m[1]}/hafs-an-asim/`;
    return u.endsWith("/") ? u : u + "/";
  }

  /** Checks which surahs exist as NNN.mp3 (and which are split into parts). */
  async function scanSurahs(folder: string) {
    const whole: number[] = [];
    const parts: number[] = [];
    const n3 = (i: number) => String(i).padStart(3, "0");
    const head = async (url: string) => {
      try { return (await fetch(url, { method: "HEAD" })).ok; } catch { return false; }
    };
    for (let start = 1; start <= 114; start += 12) {
      const batch = Array.from({ length: Math.min(12, 115 - start) }, (_, k) => start + k);
      setScan(`جاري فحص السور ${start}–${batch[batch.length - 1]} من 114...`);
      await Promise.all(batch.map(async (i) => {
        if (await head(`${folder}${n3(i)}.mp3`)) whole.push(i);
        else if (await head(`${folder}${n3(i)}-001.mp3`)) parts.push(i);
      }));
    }
    setScan("");
    return { whole: whole.sort((a, b) => a - b), parts: parts.sort((a, b) => a - b) };
  }

  async function add() {
    if (!name.trim()) return notify("اكتب اسم القارئ", false);
    let url = link.trim();
    let surahs: number[] | null = null;
    if (mode === "link") {
      if (!/^https?:\/\//.test(url)) return notify("اكتب رابطاً صحيحاً يبدأ بـ https://", false);
      url = toFolder(url);
      const { whole, parts } = await scanSurahs(url);
      if (whole.length === 0) {
        return notify(parts.length
          ? `هذا القارئ سوره مقسمة لأجزاء (${parts.length} سورة) وغير مدعومة حالياً`
          : "لم أجد ملفات سور في هذا الرابط، تأكد منه", false);
      }
      surahs = whole;
      if (parts.length) {
        notify(`تمت إضافة ${whole.length} سورة. ${parts.length} سورة مقسمة لأجزاء لم تُضف`, true);
      }
    }
    const { data, error } = await supabase.from("reciters").insert({
      name: name.trim(), riwaya: riwaya.trim() || "حفص عن عاصم",
      server_url: mode === "link" ? url : null,
      surahs: mode === "link" ? surahs : null,
      is_published: mode === "link",
    }).select("*, recitations(count)").single();
    if (error) return notify(error.message, false);
    // New reciters go to the end of «قراء مشهورون».
    const { data: last } = await supabase.from("reciter_overrides").select("sort")
      .eq("featured", true).order("sort", { ascending: false }).limit(1);
    await supabase.from("reciter_overrides").upsert({
      key: `reciter:${(data as ReciterRow).id}`, name: name.trim(),
      featured: true, hidden: false, sort: ((last?.[0]?.sort as number) ?? 0) + 10,
    }, { onConflict: "key" });
    notify(mode === "link" ? "تمت إضافة القارئ ونشره في التطبيق" : "تمت الإضافة، ارفع التلاوات ثم انشره");
    setAdding(false);
    setName("");
    setLink("");
    load();
    if (mode === "upload") setOpen(data as ReciterRow);
  }

  async function toggle(r: ReciterRow) {
    await supabase.from("reciters").update({ is_published: !r.is_published }).eq("id", r.id);
    notify(r.is_published ? "تم إخفاؤه من التطبيق" : "تم نشره في التطبيق");
    load();
  }

  async function remove(r: ReciterRow) {
    if (!confirm(`حذف ${r.name}${r.server_url ? "" : " وكل تلاواته المرفوعة"}؟`)) return;
    if (!r.server_url) {
      const { data: files } = await supabase.storage.from("media").list(`reciters/${r.id}`, { limit: 200 });
      if (files?.length) await supabase.storage.from("media").remove(files.map((f) => `reciters/${r.id}/${f.name}`));
    }
    await supabase.from("reciters").delete().eq("id", r.id);
    await supabase.from("reciter_overrides").delete().eq("key", `reciter:${r.id}`);
    notify("تم الحذف");
    load();
  }

  return (
    <>
      <div className="row" style={{ marginBottom: 14 }}>
        <span style={{ color: "var(--muted)", fontSize: 14 }}>
          القراء الذين تضيفهم يظهرون في أول صف «قراء مشهورون» في التطبيق.
        </span>
        <span className="spacer" />
        <button className="btn gold" onClick={() => setAdding(true)}><Icon name="plus" size={18} /> إضافة قارئ</button>
      </div>

      {rows === null ? <Skeleton rows={3} /> : rows.length === 0 ? (
        <div className="card"><Empty icon="mic" title="لم تضف قراء بعد"
          text="أضف قارئاً برفع ملفات السور أو بوضع رابط مجلد التلاوات"
          action={<button className="btn" onClick={() => setAdding(true)}><Icon name="plus" size={18} /> إضافة قارئ</button>} /></div>
      ) : (
        <div className="rlist">
          {rows.map((r) => {
            const n = r.server_url ? 114 : r.recitations?.[0]?.count ?? 0;
            return (
              <div className="ritem" key={r.id}>
                <div className="avatar">{r.name.charAt(0)}</div>
                <div className="info">
                  <b>{r.name}</b>
                  <span>{r.riwaya} • {r.server_url ? "من رابط" : "ملفات مرفوعة"}</span>
                </div>
                {!r.server_url && (
                  <div style={{ textAlign: "center" }}>
                    <div className="progress-mini"><i style={{ width: `${(n / 114) * 100}%` }} /></div>
                    <span style={{ fontSize: 12, color: "var(--muted)" }}>{n} / 114 سورة</span>
                  </div>
                )}
                <span className={`badge-s ${r.is_published ? "" : "off"}`}>{r.is_published ? "منشور" : "مخفي"}</span>
                {!r.server_url && <button className="btn sm" onClick={() => setOpen(r)}><Icon name="upload" size={16} /> التلاوات</button>}
                <button className="btn sm ghost" onClick={() => toggle(r)}><Icon name={r.is_published ? "eyeoff" : "eye"} size={16} /> {r.is_published ? "إخفاء" : "نشر"}</button>
                <button className="btn sm danger" onClick={() => remove(r)}><Icon name="trash" size={16} /> حذف</button>
              </div>
            );
          })}
        </div>
      )}

      {adding && (
        <Modal title="إضافة قارئ" onClose={() => setAdding(false)}
          footer={<><button className="btn ghost" onClick={() => setAdding(false)}>إلغاء</button><button className="btn" disabled={!!scan} onClick={add}>{scan ? "جاري الفحص..." : "إضافة"}</button></>}>
          <div className="stack">
            <Field label="اسم القارئ"><input value={name} onChange={(e) => setName(e.target.value)} placeholder="مثال: الشيخ محمد جمعة" /></Field>
            <Field label="الرواية / نوع التلاوة"><input value={riwaya} onChange={(e) => setRiwaya(e.target.value)} /></Field>
            <div className="seg">
              <button className={mode === "upload" ? "on" : ""} onClick={() => setMode("upload")}>رفع ملفات MP3</button>
              <button className={mode === "link" ? "on" : ""} onClick={() => setMode("link")}>رابط مجلد التلاوات</button>
            </div>
            {mode === "link" ? (
              <>
              <Field label="رابط القارئ" hint="الصق رابط صفحة القارئ من way2quran، أو رابط مجلد فيه ملفات 001.mp3 حتى 114.mp3 (مثل mp3quran). سيتم فحص السور المتاحة تلقائياً.">
                <input dir="ltr" value={link} onChange={(e) => setLink(e.target.value)} placeholder="https://way2quran.com/ar/reciters/..." />
              </Field>
              {scan && <div className="note"><Icon name="refresh" size={18} /><div>{scan}</div></div>}
              </>
            ) : (
              <div className="note"><Icon name="upload" size={18} /><div>بعد الإضافة تفتح لك نافذة رفع السور.</div></div>
            )}
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
        <div className={`drop ${over ? "over" : ""}`}
          onClick={() => input.current?.click()}
          onDragOver={(e) => { e.preventDefault(); setOver(true); }}
          onDragLeave={() => setOver(false)}
          onDrop={(e) => { e.preventDefault(); setOver(false); upload(e.dataTransfer.files); }}>
          <input ref={input} type="file" accept="audio/mpeg,audio/mp3" multiple onChange={(e) => upload(e.target.files)} />
          <div style={{ color: "var(--emerald-700)", marginBottom: 6 }}><Icon name="upload" size={28} /></div>
          {busy || <>اسحب ملفات MP3 هنا أو اضغط للاختيار<br />
            <small style={{ color: "var(--muted)" }}>ملف واحد ← للسورة المحددة ({surah}). عدة ملفات ← حسب الرقم في الاسم مثل 001.mp3</small></>}
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

// ---------------------------------------------------------------------------
// Order of «قراء مشهورون» in the app
// ---------------------------------------------------------------------------
function FeaturedOrder({ notify }: { notify: Notify }) {
  const [list, setList] = useState<Override[] | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    const { data, error } = await supabase.from("reciter_overrides")
      .select("key,name,hidden,featured,sort").eq("featured", true).eq("hidden", false)
      .order("sort");
    if (error) notify(error.message, false);
    setList((data as Override[]) ?? []);
  }, [notify]);
  useEffect(() => { load(); }, [load]);

  async function persist(next: Override[]) {
    setList(next);
    setSaving(true);
    const rows = next.map((o, i) => ({ ...o, sort: (i + 1) * 10 }));
    const { error } = await supabase.from("reciter_overrides").upsert(rows, { onConflict: "key" });
    setSaving(false);
    if (error) notify(error.message, false);
    else notify("تم حفظ الترتيب");
  }

  function move(i: number, d: -1 | 1) {
    if (!list) return;
    const j = i + d;
    if (j < 0 || j >= list.length) return;
    const next = [...list];
    [next[i], next[j]] = [next[j], next[i]];
    persist(next);
  }

  async function unstar(o: Override) {
    await supabase.from("reciter_overrides").update({ featured: false }).eq("key", o.key);
    notify(`تمت إزالة ${o.name ?? ""} من المشهورين`);
    load();
  }

  return (
    <>
      <div className="note" style={{ marginBottom: 14 }}>
        <Icon name="sparkle" size={18} />
        <div>
          هذا ترتيب صف «قراء مشهورون» في قسم الاستماع: الأول هنا يظهر أولاً في التطبيق.
          لإضافة قارئ للقائمة اضغط ★ تمييز بجانبه في «قراء التطبيق»، والقراء الذين تضيفهم يُضافون تلقائياً.
        </div>
      </div>
      {list === null ? <Skeleton rows={4} /> : list.length === 0 ? (
        <div className="card"><Empty icon="mic" title="لا يوجد قراء مميزون بعد"
          text="ميّز قراء من تبويب «قراء التطبيق» ليظهروا هنا وترتبهم" /></div>
      ) : (
        <div className="rlist">
          {list.map((o, i) => (
            <div className="ritem" key={o.key}>
              <div className="avatar" style={{ background: i < 3 ? "var(--gold)" : undefined, color: i < 3 ? "var(--emerald-900)" : undefined }}>{i + 1}</div>
              <div className="info">
                <b>{o.name ?? o.key}</b>
                <span>{o.key.startsWith("reciter:") ? "أضفته من لوحة التحكم" : o.key.startsWith("builtin:") ? "مدمج في التطبيق" : "من مكتبة mp3quran"}</span>
              </div>
              <button className="btn sm ghost" disabled={i === 0 || saving} onClick={() => move(i, -1)} aria-label="لأعلى">▲</button>
              <button className="btn sm ghost" disabled={i === list.length - 1 || saving} onClick={() => move(i, 1)} aria-label="لأسفل">▼</button>
              <button className="btn sm danger" onClick={() => unstar(o)}>إزالة</button>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
