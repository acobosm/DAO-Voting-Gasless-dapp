'use client';

import React from 'react';
import { WagmiProvider, createConfig, http } from 'wagmi';
import { hardhat } from 'wagmi/chains'; // Usaremos la definición de Hardhat/Anvil
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ANVIL_CHAIN_ID } from '../lib/config';

// 1. Configurar la cadena local (Anvil)
const localChain = {
  ...hardhat,
  id: ANVIL_CHAIN_ID,
  name: 'Anvil Localhost',
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] }, // Puerto por defecto de Anvil
  },
} as const;

// 2. Configurar Wagmi (Solo usaremos la chain local por simplicidad)
const config = createConfig({
  chains: [localChain],
  transports: {
    [localChain.id]: http(),
  },
});

// 3. Configurar el cliente de consultas (necesario para Wagmi)
const queryClient = new QueryClient();

// Componente Proveedor
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
}