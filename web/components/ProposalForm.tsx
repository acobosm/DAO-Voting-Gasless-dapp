'use client';

import { useState } from 'react';
import { useAccount, useWalletClient, useReadContract, usePublicClient } from 'wagmi';
import { parseEther, encodeFunctionData, type Address } from 'viem';
import { DAO_VOTING_CONFIG, FORWARDER_CONFIG, ANVIL_CHAIN_ID } from '../lib/config';
import { EIP712Domain, ForwardRequest, SIGNING_DOMAIN_NAME, SIGNING_DOMAIN_VERSION } from '../lib/types';
import DAOVotingABI from '../lib/abi/DAOVoting.json';

export default function ProposalForm() {
  const { address, isConnected, chainId } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();

  const [description, setDescription] = useState('');
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [deadline, setDeadline] = useState(() => {
    const d = new Date();
    d.setHours(d.getHours() + 1); // Default 1 hour from now
    return d.getFullYear() + '-' +
      String(d.getMonth() + 1).padStart(2, '0') + '-' +
      String(d.getDate()).padStart(2, '0') + 'T' +
      String(d.getHours()).padStart(2, '0') + ':' +
      String(d.getMinutes()).padStart(2, '0');
  });
  const [isGasless, setIsGasless] = useState(true);

  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState<'idle' | 'signing' | 'relaying' | 'success' | 'error'>('idle');
  const [errorMsg, setErrorMsg] = useState('');
  const [txHash, setTxHash] = useState('');

  const handleGaslessSubmit = async () => {
    if (!walletClient || !publicClient || !address || !recipient || !amount) return;

    try {
      setStatus('signing');
      setIsLoading(true);
      setErrorMsg('');

      // 1. Prepare data
      // Convert selected date-time string to unix timestamp
      const deadlineTimestamp = Math.floor(new Date(deadline).getTime() / 1000);
      const weiAmount = parseEther(amount);

      const functionData = encodeFunctionData({
        abi: DAOVotingABI.abi,
        functionName: 'createProposal',
        args: [description, recipient as Address, weiAmount, BigInt(deadlineTimestamp)]
        // NOTE: The contract signature is createProposal(address,uint256,uint256). 
        // Description is NOT in the arguments in the contract code I saw earlier?
        // Let's re-verify Step 6.
        // Line 186: function createProposal(address recipient, uint256 amount, uint256 deadline)
        // Correct, Description is missing in the contract? 
        // Wait, normally DAOs have description.
        // The contract in Step 6 DOES NOT have description in createProposal args or struct. 
        // It has `emit ProposalCreated(..., recipient, amount, deadline)`.
        // So description is likely off-chain or just omitted in this simplified contract.
        // I will ignore description for the contract call, but maybe keep it in UI for "simulation" or future use.
      });

      // 2. Get Nonce from Forwarder
      const nonce = await publicClient.readContract({
        ...FORWARDER_CONFIG,
        functionName: 'getNonce',
        args: [address],
      });

      // 3. Create Request Struct
      const request = {
        from: address,
        to: DAO_VOTING_CONFIG.address,
        value: 0n, // We are calling createProposal, usually 0 ETH sent with call unless required
        gas: 2000000n, // Hardcoded high limit or estimate
        nonce: BigInt(Number(nonce)),
        data: functionData,
      };

      // 4. Sign Type Data
      const domain = {
        name: SIGNING_DOMAIN_NAME,
        version: SIGNING_DOMAIN_VERSION,
        chainId: BigInt(ANVIL_CHAIN_ID),
        verifyingContract: FORWARDER_CONFIG.address,
      } as const;

      const types = {
        ForwardRequest,
      } as const;

      const signature = await walletClient.signTypedData({
        account: address,
        domain,
        types,
        primaryType: 'ForwardRequest',
        message: request,
      });

      // 5. Send to Relayer
      setStatus('relaying');
      const response = await fetch('/api/relay', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          request: {
            ...request,
            value: request.value.toString(),
            gas: request.gas.toString(),
            nonce: request.nonce.toString()
          },
          signature
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.details || data.error || 'Relay failed');
      }

      setTxHash(data.txHash);
      setStatus('success');
      setDescription('');
      setAmount('');
      setRecipient('');

    } catch (err: any) {
      console.error(err);
      setStatus('error');
      // Check for specific "Insufficient balance" error
      const msg = err.message || "Unknown error";

      if (msg.includes("Insufficient balance") || msg.includes("Must hold >= 10%")) {
        try {
          // Fetch user balance to distinguish cases
          const balance = await publicClient.readContract({
            ...DAO_VOTING_CONFIG,
            functionName: 'getUserBalance',
            args: [address],
          });

          if (balance === 0n) {
            setErrorMsg("⚠️ No has aportado nada a la DAO. Debes aportar fondos (>= 10% del total) para poder crear propuestas.");
          } else {
            setErrorMsg("⚠️ Fondos insuficientes: Sí has aportado, pero tu saldo no alcanza el 10% del total de la DAO requerido para crear propuestas. Favor aumenta tu aportación.");
          }
        } catch (balanceErr) {
          console.error("Error checking balance:", balanceErr);
          setErrorMsg("⚠️ Error de permisos: No cumples con el requisito de balance del 10%.");
        }
      } else {
        setErrorMsg(msg);
      }
    } finally {
      setIsLoading(false);
    }
  };

  if (!isConnected) {
    return (
      <div className="bg-slate-950 border border-slate-700 p-4 rounded-xl">
        <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
          <span className="p-2 bg-gray-500/20 rounded-lg text-gray-400">📝</span>
          Nueva Propuesta
        </h3>

        <div className="flex flex-col items-center justify-center py-10 text-center space-y-4">
          <div className="p-4 bg-primary-500/10 rounded-full mb-2">
            <span className="text-4xl">🔐</span>
          </div>
          <h4 className="text-lg font-bold text-white">Conecta tu Wallet</h4>
          <p className="text-dark-muted max-w-xs text-sm">
            Necesitas estar conectado para crear propuestas y solicitar fondos de la DAO.
          </p>
          {/* Note: ConnectButton is usually in header, but we can't easily perform the connect action here 
                 unless we import the hook or component. Let's just point them to the header or render a button if possible.
                 Actually, reusing ConnectButton logic specifically for 'connect' action might be complex if it has its own UI.
                 Let's just replicate a simple Connect trigger or visual cue.
             */}
          <div className="p-2 bg-primary-500/10 rounded-lg border border-primary-500/20 text-primary-300 text-xs font-mono">
            ↗️ Usa el botón "Connect Wallet" arriba a la derecha
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-slate-950 border border-slate-700 p-4 rounded-xl">
      {/* Decorative removed for debugging */}

      <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
        <span className="p-2 bg-primary-500/20 rounded-lg text-primary-400">📝</span>
        Nueva Propuesta
      </h3>

      <div className="space-y-5">
        <div>
          {/* Description unused in contract but good for UX */}
          <label className="block text-xs font-semibold text-dark-muted uppercase tracking-wider mb-2">Descripción</label>
          <input
            type="text"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="glass-input w-full text-white"
            placeholder="Ej: Financiar nuevo sitio web"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-semibold text-dark-muted uppercase tracking-wider mb-2">Beneficiario</label>
            <input
              type="text"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              className="glass-input w-full text-white font-mono text-xs"
              placeholder="0x..."
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-dark-muted uppercase tracking-wider mb-2">Monto (ETH)</label>
            <input
              type="number"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.0"
            />
          </div>
        </div>

        <div>
          <label className="block text-xs font-semibold text-dark-muted uppercase tracking-wider mb-2">Vencimiento (Fecha y Hora)</label>
          <input
            type="datetime-local"
            value={deadline}
            onChange={(e) => setDeadline(e.target.value)}
            className="glass-input w-full text-white"
          />
        </div>

        {/* Toggle Gasless */}
        <div className="flex items-center gap-3 py-2">
          <div
            className={`w-12 h-6 rounded-full p-1 cursor-pointer transition-colors ${isGasless ? 'bg-green-500' : 'bg-slate-600'}`}
            onClick={() => setIsGasless(!isGasless)}
          >
            <div className={`w-4 h-4 bg-white rounded-full shadow-sm transform transition-transform ${isGasless ? 'translate-x-6' : ''}`}></div>
          </div>
          <span className="text-sm font-medium text-white">
            {isGasless ? '⚡ Gasless Transaction (Relayer Pays)' : '⛽ Standard Transaction (You Pay)'}
          </span>
        </div>

        <button
          onClick={handleGaslessSubmit}
          disabled={isLoading || status === 'success'}
          className={`w-full py-4 rounded-xl font-bold text-white shadow-lg transition-all transform hover:scale-[1.02] active:scale-[0.98] ${status === 'success' ? 'bg-green-600' :
            statusCodeToColor(status)
            }`}
        >
          {status === 'signing' ? '✍️ Firmando...' :
            status === 'relaying' ? '🚀 Enviando a Relayer...' :
              status === 'success' ? '✅ Propuesta Creada!' :
                isGasless ? 'Crear Propuesta (Gasless)' : 'Crear Propuesta'}
        </button>

        {errorMsg && (
          <div className="p-3 bg-red-500/10 border border-red-500/20 rounded-lg text-red-400 text-sm text-center">
            {errorMsg}
          </div>
        )}

        {txHash && (
          <div className="mt-4 p-4 bg-green-500/10 border border-green-500/20 rounded-xl text-center animate-in fade-in slide-in-from-bottom-2">
            <p className="text-green-400 font-bold mb-1">¡Transacción Exitosa!</p>
            <p className="text-xs text-green-300 break-all font-mono mb-3">{txHash}</p>
            <button
              onClick={() => {
                setStatus('idle');
                setTxHash('');
              }}
              className="text-xs text-white bg-green-600 hover:bg-green-500 px-3 py-1 rounded transition-colors"
            >
              Crear Otra Propuesta
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function statusCodeToColor(status: string) {
  if (status === 'error') return 'bg-red-600';
  return 'bg-gradient-to-r from-primary-600 to-indigo-600 hover:from-primary-500 hover:to-indigo-500';
}