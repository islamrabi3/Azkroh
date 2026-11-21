"use client";

import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "@/lib/supabase";
import Overview from "./tabs/overview";
import Questions from "./tabs/questions";
import Generate from "./tabs/generate";
import Content from "./tabs/content";
import Reciters from "./tabs/reciters";

const TABS = [
  ["overview", "نظرة عامة"],
  ["questions", "الأسئلة"],
  ["generate", "توليد أسئلة بالذكاء الاصطناعي"],
  ["content", "المحتوى (فيديوهات وروابط)"],
  ["reciters", "القراء والتلاوات"],
] as const;
type Tab = (typeof TABS)[number][0];

export default function Page() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [tab, setTab] = useState<Tab>("overview");

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) =>
      setSession(s),
    );
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) return setIsAdmin(false);
    supabase.rpc("is_admin").then(({ data }) => setIsAdmin(data === true));
  }, [session]);

  if (!ready) return <p className="center muted">...</p>;
  if (!session) return <Login />;
  if (!isAdmin) {
    return (
      <div className="login">
        <h1>غير مصرح</h1>
        <p className="muted">هذا الحساب ليس مسؤولاً عن لوحة التحكم.</p>
        <button onClick={() => supabase.auth.signOut()}>تسجيل الخروج</button>
      </div>
    );
  }

  return (
    <>
      <div className="topbar">
        <h1>لوحة تحكم أذكروه</h1>
        <span className="who">{session.user.email}</span>
        <button className="ghost small" style={{ color: "#fff", borderColor: "#ffffff55" }}
          onClick={() => supabase.auth.signOut()}>
          خروج
        </button>
      </div>
      <div className="tabs">
        {TABS.map(([id, label]) => (
          <button key={id} className={tab === id ? "active" : ""}
            onClick={() => setTab(id)}>
            {label}
          </button>
        ))}
      </div>
      <div className="wrap">
        {tab === "overview" && <Overview />}
        {tab === "questions" && <Questions />}
        {tab === "generate" && <Generate onDone={() => setTab("questions")} />}
        {tab === "content" && <Content />}
        {tab === "reciters" && <Reciters />}
      </div>
    </>
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
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setErr("البريد أو كلمة المرور غير صحيحة");
    setBusy(false);
  }

  return (
    <form className="login" onSubmit={submit}>
      <h1>أذكروه</h1>
      <p className="muted">لوحة التحكم — تسجيل دخول المسؤول</p>
      {err && <div className="msg err">{err}</div>}
      <label>البريد الإلكتروني</label>
      <input type="email" value={email} onChange={(e) => setEmail(e.target.value)}
        autoComplete="username" required dir="ltr" />
      <label>كلمة المرور</label>
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
        autoComplete="current-password" required dir="ltr" />
      <div style={{ marginTop: 16 }}>
        <button type="submit" disabled={busy} style={{ width: "100%" }}>
          {busy ? "..." : "دخول"}
        </button>
      </div>
    </form>
  );
}
