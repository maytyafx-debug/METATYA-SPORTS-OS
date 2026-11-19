import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "METATYA SPORT OS", description: "سامانه جامع مدیریت و هوشمندسازی ورزش" };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="fa" dir="rtl"><body>{children}</body></html>; }
