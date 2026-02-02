'use client';

import { useState, useEffect } from 'react';
import { useAccount, useConnect, useDisconnect, useChainId } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { ANVIL_CHAIN_ID } from '../lib/config';

export default function ConnectButton() {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();
  const currentChainId = useChainId();

  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  if (!mounted) {
    return (
      <button className="px-6 py-2.5 rounded-xl font-medium text-white/50 bg-white/5 animate-pulse cursor-wait">
        Loading...
      </button>
    );
  }

  if (!isConnected) {
    return (
      <button
        onClick={() => connect({ connector: injected() })}
        className="relative group px-6 py-2.5 rounded-xl font-medium text-white shadow-lg shadow-primary-500/25 overflow-hidden transition-all hover:scale-105 active:scale-95"
      >
        <div className="absolute inset-0 bg-gradient-to-r from-primary-600 to-indigo-600 group-hover:from-primary-500 group-hover:to-indigo-500 transition-colors" />
        <span className="relative flex items-center gap-2">
          <span>Conectar Billetera</span>
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
          </svg>
        </span>
      </button>
    );
  }

  const displayAddress = address ? `${address.slice(0, 6)}...${address.slice(-4)}` : '';
  const isCorrectChain = currentChainId === ANVIL_CHAIN_ID;

  return (
    <div className="flex items-center gap-4">
      {/* Chain Indicator */}
      <div className={`hidden md:flex items-center px-3 py-1 rounded-full text-xs font-semibold border ${isCorrectChain
        ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'
        : 'bg-red-500/10 border-red-500/20 text-red-400'
        }`}>
        <span className={`w-2 h-2 rounded-full mr-2 ${isCorrectChain ? 'bg-emerald-400 animate-pulse' : 'bg-red-400'}`}></span>
        {isCorrectChain ? 'Anvil Network' : 'Red Incorrecta'}
      </div>

      {/* Wallet Info */}
      <div className="flex items-center gap-3 pl-4 pr-2 py-1.5 bg-slate-800 border border-slate-700 rounded-full">
        <div className="hidden sm:flex flex-col text-right mr-1">
          <span className="text-[10px] text-dark-muted font-medium uppercase tracking-wider">Conectado como</span>
          <span className="text-sm font-bold bg-gradient-to-r from-blue-200 to-indigo-200 bg-clip-text text-transparent">
            {displayAddress}
          </span>
        </div>

        <div className="h-8 w-8 rounded-full bg-gradient-to-br from-primary-400 to-indigo-500 p-[2px]">
          <div className="h-full w-full rounded-full bg-slate-900 flex items-center justify-center">
            <span className="text-xs">👤</span>
          </div>
        </div>

        <button
          onClick={() => disconnect()}
          className="ml-2 p-2 hover:bg-white/10 rounded-full text-dark-muted hover:text-white transition-colors"
          title="Desconectar"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
          </svg>
        </button>
      </div>
    </div>
  );
}