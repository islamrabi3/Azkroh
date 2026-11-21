import { createClient } from "@supabase/supabase-js";

// Public values only. Row level security decides what each user can do;
// writes require an account whose app_metadata.role is "admin".
const url =
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  "https://ubdcbknyloaupoozfhnx.supabase.co";
const key =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  "sb_publishable_8uoh_b0RHwQrVZlFbuRYKA_s3-Wdk80";

export const supabase = createClient(url, key, {
  auth: { persistSession: true, autoRefreshToken: true },
});

export type Question = {
  id: string;
  category: string;
  difficulty: number;
  question: string;
  options: string[];
  correct: number;
  explanation: string | null;
  source: string | null;
  status: "pending" | "approved" | "rejected";
  created_at: string;
};

export type ContentItem = {
  id: string;
  kind: "video" | "link" | "playlist" | "article" | "pdf" | "audio";
  section: string;
  title: string;
  description: string | null;
  url: string;
  thumbnail_url: string | null;
  sort: number;
  is_published: boolean;
};

export type Reciter = {
  id: string;
  name: string;
  riwaya: string;
  group_name: string | null;
  is_published: boolean;
  sort: number;
};

export type Recitation = {
  id: string;
  reciter_id: string;
  surah: number;
  url: string;
};

export const CATEGORIES: Record<string, string> = {
  seerah: "سيرة النبي ﷺ",
  companions: "الصحابة",
  battles: "الغزوات",
  quran: "أسئلة في القرآن",
  prophets: "الأنبياء",
  general: "معلومات دينية",
};

export const STATUS: Record<string, string> = {
  pending: "بانتظار المراجعة",
  approved: "معتمد",
  rejected: "مرفوض",
};
