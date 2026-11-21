"use client";

import { useCallback, useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import { Icon, Toast, ToastMsg } from "@/lib/ui";
import Overview from "./tabs/overview";
import Questions from "./tabs/questions";
import Generate from "./tabs/generate";
import Content from "./tabs/content";
import Reciters from "./tabs/reciters";

const NAV = [
  { id: "overview", label: "الرئيسية", icon: "home" },
  { id: "questions", label: "الأسئلة", icon: "quiz" },
  { id: "generate", label: "توليد بالذكاء الاصطناعي", icon: "sparkle" },
  { id: "content", label: "الفيديوهات والروابط", icon: "play" },
  { id: "reciters", label: "القراء والتلاوات", icon: "mic" },
] as const;
export type Tab = (typeof NAV)[number]["id"];

export type Notify = (text: string, ok?: boolean) => void;

export default function Page() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [tab, setTab] = useState<Tab>("overview");
  const [menu, setMenu] = useState(false);
  const [pending, setPending] = useState(0);
  const [toast, setToast] = useState<ToastMsg>(null);

  const notify: Notify = useCallback((text, ok = true) => setToast({ text, ok }), []);
  const clearToast = useCallback(() => setToast(null), []);

  useEffect(() => {
    // Local screenshot builds only (NEXT_PUBLIC_DEV_SESSION=1 is never set in production).
    if (process.env.NEXT_PUBLIC_DEV_SESSION === "1") {
      const h = new URLSearchParams(window.location.hash.slice(1));
      const at = h.get("at"), rt = h.get("rt"), t = h.get("tab");
      if (t) setTab(t as Tab);
      if (at && rt) supabase.auth.setSession({ access_token: at, refresh_token: rt });
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) return setIsAdmin(null);
    supabase.rpc("is_admin").then(({ data }) => setIsAdmin(data === true));
  }, [session]);

  const refreshPending = useCallback(async () => {
    const { count } = await supabase
      .from("questions")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending");
    setPending(count ?? 0);
  }, []);

  useEffect(() => {
    if (isAdmin) refreshPending();
  }, [isAdmin, tab, refreshPending]);

  if (!ready) return null;
  if (!session) return <Login />;
  if (isAdmin === null) return null;
  if (!isAdmin) {
    return (
      <div className="auth-form" style={{ minHeight: "100vh" }}>
        <div className="card" style={{ maxWidth: 380, textAlign: "center" }}>
          <h3>غير مصرح</h3>
          <p style={{ color: "var(--muted)" }}>هذا الحساب ليس مسؤولاً عن لوحة التحكم.</p>
          <button className="btn" onClick={() => supabase.auth.signOut()}>تسجيل الخروج</button>
        </div>
      </div>
    );
  }

  const go = (t: Tab) => {
    setTab(t);
    setMenu(false);
    window.scrollTo({ top: 0 });
  };
  const email = session.user.email ?? "";

  return (
    <div className="shell">
      <div className="mobile-bar">
        <img src="/logo.png" alt="" />
        <b>أذكروه</b>
        <button className="icon-btn" aria-label="القائمة" onClick={() => setMenu(true)}>
          <Icon name="menu" />
        </button>
      </div>
      {menu && <div className="scrim" onClick={() => setMenu(false)} />}

      <aside className={`sidebar ${menu ? "open" : ""}`}>
        <div className="brand">
          <img src="/logo.png" alt="" />
          <div>
            <b>أذكروه</b>
            <span>لوحة التحكم</span>
          </div>
        </div>
        <nav className="nav">
          {NAV.map((n) => (
            <button key={n.id} className={tab === n.id ? "active" : ""} onClick={() => go(n.id)}>
              <Icon name={n.icon} />
              {n.label}
              {n.id === "questions" && pending > 0 && <span className="badge">{pending}</span>}
            </button>
          ))}
        </nav>
        <div className="user">
          <div className="avatar">{email.charAt(0).toUpperCase()}</div>
          <div className="who">
            <b>المسؤول</b>
            <span dir="ltr">{email}</span>
          </div>
          <button className="icon-btn" title="تسجيل الخروج" aria-label="تسجيل الخروج"
            onClick={() => supabase.auth.signOut()}>
            <Icon name="logout" />
          </button>
        </div>
      </aside>

      <main className="main">
        {tab === "overview" && <Overview go={go} notify={notify} />}
        {tab === "questions" && <Questions notify={notify} onChange={refreshPending} />}
        {tab === "generate" && <Generate notify={notify} go={go} />}
        {tab === "content" && <Content notify={notify} />}
        {tab === "reciters" && <Reciters notify={notify} />}
      </main>
      <Toast msg={toast} onDone={clearToast} />
    </div>
  );
}

function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error) setErr("البريد الإلكتروني أو كلمة المرور غير صحيحة");
    setBusy(false);
  }

  return (
    <div className="auth">
      <section className="auth-brand">
        <img src="/logo.png" alt="أذكروه" />
        <h1>أذكروه</h1>
        <p>أدر الأسئلة والمسابقات والمحتوى والقراء، وكل ما تنشره يصل إلى التطبيق مباشرة.</p>
        <div className="ayah">﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾</div>
      </section>
      <section className="auth-form">
        <form onSubmit={submit}>
          <h2>تسجيل الدخول</h2>
          <p className="sub">للمسؤولين فقط</p>
          {err && <div className="alert">{err}</div>}
          <div className="field">
            <label htmlFor="email">البريد الإلكتروني</label>
            <input id="email" type="email" dir="ltr" value={email} required
              autoComplete="username" onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="pw">كلمة المرور</label>
            <input id="pw" type="password" dir="ltr" value={password} required
              autoComplete="current-password" onChange={(e) => setPassword(e.target.value)} />
          </div>
          <button className="btn block" type="submit" disabled={busy} style={{ height: 46 }}>
            {busy ? "جاري الدخول..." : "دخول"}
          </button>
        </form>
      </section>
    </div>
  );
}
