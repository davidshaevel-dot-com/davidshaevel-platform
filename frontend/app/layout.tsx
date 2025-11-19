import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Navigation from "@/components/Navigation";
import Footer from "@/components/Footer";
import { MetricsProvider } from "@/components/MetricsProvider";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "David Shaevel - Platform Engineer",
  description: "Platform engineering portfolio showcasing AWS cloud architecture, infrastructure as code, and DevOps expertise.",
  keywords: ["Platform Engineering", "DevOps", "AWS", "Terraform", "Infrastructure as Code", "Cloud Architecture"],
  authors: [{ name: "David Shaevel" }],
  creator: "David Shaevel",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} font-sans antialiased`}>
        <MetricsProvider>
          <div className="flex min-h-screen flex-col">
            <Navigation />
            <main className="flex-1">{children}</main>
            <Footer />
          </div>
        </MetricsProvider>
      </body>
    </html>
  );
}
