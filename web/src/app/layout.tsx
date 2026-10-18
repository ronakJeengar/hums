import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "@/components/providers";

export const metadata: Metadata = {
  title: "Hums — Admin Panel & Creator Studio",
  description: "Enterprise Operations and Creator Studio for Hums Audio Platform",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark h-full antialiased">
      <body className="min-h-full bg-slate-950 text-slate-100 flex flex-col">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
