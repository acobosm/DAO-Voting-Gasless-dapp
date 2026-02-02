import { Providers } from './providers';
import './globals.css';

export const metadata = {
  title: 'DAO Voting | Gasless Platform',
  description: 'Vote on proposals without paying gas',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="es" className="dark">
      <body className="bg-dark-bg text-dark-text antialiased min-h-screen">
        {/* Background Gradients */}
        <div className="fixed inset-0 -z-10 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-indigo-900/20 via-slate-900 to-slate-900 pointer-events-none" />
        <div className="fixed inset-0 -z-10 bg-[url('/grid.svg')] bg-center [mask-image:linear-gradient(180deg,white,rgba(255,255,255,0))]" />

        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}