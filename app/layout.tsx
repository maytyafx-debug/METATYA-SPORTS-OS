import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "METATYA Sports OS", description: "سامانه عمومی مدیریت باشگاه‌های ورزشی" };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="fa" dir="rtl"><body>{children}</body></html>; }
