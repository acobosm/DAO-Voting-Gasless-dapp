'use client';

import ConnectButton from '../components/ConnectButton';
import ProposalForm from '../components/ProposalForm';
import ProposalList from '../components/ProposalList';
import DAOStats from '../components/DAOStats';

export default function Home() {
  return (
    <main className="min-h-screen bg-black text-slate-200 font-sans p-4 md:p-8">

      {/* 1. Header Section */}
      <header className="max-w-4xl mx-auto mb-12 flex flex-col md:flex-row items-center justify-between gap-6 border-b border-slate-800 pb-6">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">DAO Voting</h1>
          <p className="text-slate-500 text-sm">Panel de Control Simplificado</p>
        </div>
        <ConnectButton />
      </header>

      {/* 2. Main Content Stack (Grid Layout for Stability) */}
      <div className="max-w-2xl mx-auto grid grid-cols-1 gap-16 relative">

        {/* SECTION A: Treasury & Personal Action */}
        <section className="bg-slate-900 border border-slate-800 rounded-xl p-6 shadow-sm relative z-20">
          <h2 className="text-xl font-bold text-white mb-6 border-b border-slate-700 pb-2">1. Finanzas</h2>
          <DAOStats />
        </section>

        {/* SECTION B: Create Proposal */}
        <section className="bg-slate-900 border border-slate-800 rounded-xl p-6 shadow-sm relative z-10">
          <h2 className="text-xl font-bold text-white mb-6 border-b border-slate-700 pb-2">2. Crear Propuesta</h2>
          <ProposalForm />
        </section>

        {/* SECTION C: Proposal List */}
        <section className="bg-slate-900 border border-slate-800 rounded-xl p-6 shadow-sm relative z-0">
          <div className="flex justify-between items-center mb-6 border-b border-slate-700 pb-2">
            <h2 className="text-xl font-bold text-white">3. Votaciones</h2>
            <span className="bg-green-900 text-green-300 text-xs px-2 py-1 rounded">En Tiempo Real</span>
          </div>
          <ProposalList />
        </section>

      </div>

      {/* Footer */}
      <footer className="mt-20 text-center text-slate-600 text-xs pb-10">
        <p>Sistema de Votación Gasless v2.0 - Diseño Simplificado</p>
      </footer>
    </main>
  );
}