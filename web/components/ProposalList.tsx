'use client';

import { useReadContract, useWalletClient, useAccount, usePublicClient } from 'wagmi';
import { DAO_VOTING_CONFIG, FORWARDER_CONFIG, ANVIL_CHAIN_ID } from '../lib/config';
import { EIP712Domain, ForwardRequest, SIGNING_DOMAIN_NAME, SIGNING_DOMAIN_VERSION } from '../lib/types';
import DAOVotingABI from '../lib/abi/DAOVoting.json';
import { formatEther, encodeFunctionData } from 'viem';
import { useState } from 'react';

// Voting Options
const VOTE_NONE = 0;
const VOTE_ABSTAIN = 1;
const VOTE_FOR = 2;
const VOTE_AGAINST = 3;

export default function ProposalList() {
    const { data: nextId } = useReadContract({
        ...DAO_VOTING_CONFIG,
        functionName: 'nextProposalId', // watch: true if possible or refetch
        query: { refetchInterval: 3000 }
    });

    const fetchedId = nextId ? Number(nextId) : 1;
    const proposalIds = Array.from({ length: fetchedId - 1 }, (_, i) => fetchedId - 1 - i);

    if (proposalIds.length === 0) {
        return (
            <div className="text-center py-10 px-6 bg-slate-800 border border-dashed border-slate-600 rounded-xl">
                <div className="w-16 h-16 bg-slate-700 rounded-full flex items-center justify-center mb-4 mx-auto text-3xl">
                    📭
                </div>
                <h3 className="text-xl font-bold text-white mb-2">Lista Vacía</h3>
                <p className="text-slate-400 max-w-sm mx-auto">
                    Aún no hay propuestas. Usa el formulario de la izquierda (borde morado) para crear una.
                </p>
            </div>
        );
    }

    return (
        <div className="space-y-4 w-full">
            {proposalIds.map((id) => (
                <ProposalItem key={id} id={id} />
            ))}
        </div>
    );
}

function ProposalItem({ id }: { id: number }) {
    const { address } = useAccount();
    const { data: walletClient } = useWalletClient();
    const publicClient = usePublicClient();
    const [votingStatus, setVotingStatus] = useState<string>('');
    const [executeStatus, setExecuteStatus] = useState<string>('');
    const [errorMessage, setErrorMessage] = useState<string>('');

    const { data: proposal, isLoading } = useReadContract({
        ...DAO_VOTING_CONFIG,
        functionName: 'getProposal',
        args: [BigInt(id)],
        query: { refetchInterval: 5000 }
    });

    // Check if user voted
    const { data: userVote } = useReadContract({
        ...DAO_VOTING_CONFIG,
        functionName: 'getUserVote',
        args: [BigInt(id), address || '0x0000000000000000000000000000000000000000'],
        query: { enabled: !!address, refetchInterval: 5000 }
    });

    if (isLoading || !proposal) return <div className="h-24 bg-slate-700 animate-pulse rounded-xl"></div>;

    const p: any = proposal;
    const deadlineDate = new Date(Number(p.deadline) * 1000);
    const now = new Date();
    const isExpired = now > deadlineDate;
    const isActive = !p.executed && !isExpired;

    const userVoteNum = Number(userVote);

    const handleVote = async (voteType: number) => {
        if (!walletClient || !publicClient || !address) return;
        setVotingStatus('signing');

        try {
            const functionData = encodeFunctionData({
                abi: DAOVotingABI.abi,
                functionName: 'vote',
                args: [BigInt(id), voteType]
            });

            const nonce = await publicClient.readContract({
                ...FORWARDER_CONFIG,
                functionName: 'getNonce',
                args: [address],
            });

            const request = {
                from: address,
                to: DAO_VOTING_CONFIG.address,
                value: 0n,
                gas: 500000n, // Vote gas limit
                nonce: nonce,
                data: functionData,
            };

            const domain = {
                name: SIGNING_DOMAIN_NAME,
                version: SIGNING_DOMAIN_VERSION,
                chainId: BigInt(ANVIL_CHAIN_ID),
                verifyingContract: FORWARDER_CONFIG.address,
            } as const;

            const types = { ForwardRequest } as const;

            const signature = await walletClient.signTypedData({
                account: address,
                domain,
                types,
                primaryType: 'ForwardRequest',
                message: request,
            });

            setVotingStatus('relaying');
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
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.details || errorData.error || 'Vote relay failed');
            }
            setVotingStatus('success');
            setTimeout(() => setVotingStatus(''), 3000);

        } catch (e: any) {
            console.error(e);
            setVotingStatus('error');

            const msg = e.message || 'Error executing vote';
            if (msg.includes('User must have a deposited balance') || msg.includes('balance to vote')) {
                setErrorMessage('⚠️ No tienes derecho al voto: Debes aportar fondos a la DAO primero.');
            } else {
                setErrorMessage(`❌ Error: ${msg.slice(0, 50)}${msg.length > 50 ? '...' : ''}`);
            }

            setTimeout(() => {
                setVotingStatus('');
                setErrorMessage('');
            }, 4000);
        }
    };

    const handleExecute = async () => {
        if (!walletClient || !publicClient || !address) return;
        setExecuteStatus('signing');

        try {
            const functionData = encodeFunctionData({
                abi: DAOVotingABI.abi,
                functionName: 'executeProposal',
                args: [BigInt(id)]
            });

            const nonce = await publicClient.readContract({
                ...FORWARDER_CONFIG,
                functionName: 'getNonce',
                args: [address],
            });

            const request = {
                from: address,
                to: DAO_VOTING_CONFIG.address,
                value: 0n,
                gas: 500000n, // Execute gas limit
                nonce: nonce ? BigInt(Number(nonce)) : 0n,
                data: functionData,
            };

            const domain = {
                name: SIGNING_DOMAIN_NAME,
                version: SIGNING_DOMAIN_VERSION,
                chainId: BigInt(ANVIL_CHAIN_ID),
                verifyingContract: FORWARDER_CONFIG.address,
            } as const;

            const types = { ForwardRequest } as const;

            const signature = await walletClient.signTypedData({
                account: address,
                domain,
                types,
                primaryType: 'ForwardRequest',
                message: request,
            });

            setExecuteStatus('relaying');
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
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.details || errorData.error || 'Execution relay failed');
            }
            setExecuteStatus('success');
            // Refresh logic handled by refetchInterval eventually, or manual reload
            setTimeout(() => setExecuteStatus(''), 5000);

        } catch (e: any) {
            console.error(e);
            setExecuteStatus('error');
            setErrorMessage(`❌ Error executing: ${e.message.slice(0, 50)}...`);
            setTimeout(() => {
                setExecuteStatus('');
                setErrorMessage('');
            }, 5000);
        }
    };

    return (
        <div className="bg-slate-900 border border-slate-700 rounded-xl overflow-hidden p-4">
            {/* Header */}
            <div className="flex justify-between items-start mb-4">
                <div>
                    <span className="text-xl font-bold text-slate-500 mr-2">#{p.id.toString()}</span>
                    <span className="text-white font-bold text-lg">{p.description || "Solicitud de Fondos"}</span>
                    <p className="text-xs text-slate-400 font-mono mt-1">Beneficiario: {p.recipient}</p>
                </div>
                <StatusBadge executed={p.executed} expired={isExpired} />
            </div>

            <div className="grid grid-cols-2 gap-4 mb-4 text-sm bg-slate-800 p-2 rounded">
                <div>
                    <p className="text-xs text-slate-400">Monto</p>
                    <p className="font-mono text-white font-bold">{formatEther(p.amount)} ETH</p>
                </div>
                <div>
                    <p className="text-xs text-slate-400">Deadline</p>
                    <p className="text-white text-xs font-mono">{deadlineDate.toLocaleString()}</p>
                </div>
            </div>

            {/* Votes */}
            <div className="space-y-2 mb-4">
                <VoteBar label="For" count={p.votesFor} total={p.votesFor + p.votesAgainst + p.votesAbstain} color="bg-green-500" />
                <VoteBar label="Against" count={p.votesAgainst} total={p.votesFor + p.votesAgainst + p.votesAbstain} color="bg-red-500" />
                <VoteBar label="Abstain" count={p.votesAbstain} total={p.votesFor + p.votesAgainst + p.votesAbstain} color="bg-slate-500" />
            </div>

            {/* Action Area */}
            {isActive && address && (
                <div className="flex gap-2 justify-end">
                    <button onClick={() => handleVote(VOTE_FOR)} disabled={!!votingStatus} className="px-3 py-1 rounded bg-green-900 text-green-200 text-sm hover:bg-green-800 transition-colors">
                        👍 For
                    </button>
                    <button onClick={() => handleVote(VOTE_AGAINST)} disabled={!!votingStatus} className="px-3 py-1 rounded bg-red-900 text-red-200 text-sm hover:bg-red-800 transition-colors">
                        👎 Against
                    </button>
                    <button onClick={() => handleVote(VOTE_ABSTAIN)} disabled={!!votingStatus} className="px-3 py-1 rounded bg-slate-700 text-slate-200 text-sm hover:bg-slate-600 transition-colors">
                        🤐 Abs
                    </button>
                </div>
            )}
            {votingStatus === 'error' ? (
                <p className="text-center text-xs mt-2 text-red-400 font-bold bg-red-900/30 p-2 rounded">{errorMessage}</p>
            ) : votingStatus && (
                <p className="text-center text-xs mt-2 text-yellow-400 animate-pulse">{votingStatus}...</p>
            )}

            {/* Execution Section - Always visible if not executed, disabled states handled */}
            {!p.executed && (
                <div className="mt-4 border-t border-slate-700 pt-3">
                    {isExpired ? (
                        <p className="text-center text-xs text-orange-400 mb-2">
                            {p.votesFor > p.votesAgainst ? "✅ Aprobada para ejecución" : "❌ Rechazada (Votos insuficientes)"}
                        </p>
                    ) : (
                        <p className="text-center text-xs text-slate-500 mb-2">
                            ⏳ Ejecución disponible al finalizar el plazo
                        </p>
                    )}

                    <button
                        onClick={handleExecute}
                        disabled={!isExpired || !!executeStatus || (isExpired && p.votesFor <= p.votesAgainst)}
                        className={`w-full py-2 rounded font-bold text-white text-sm transition-colors 
                           ${executeStatus === 'success' ? 'bg-green-600' :
                                (!isExpired || (isExpired && p.votesFor <= p.votesAgainst)) ? 'bg-slate-700 text-slate-400 cursor-not-allowed' :
                                    'bg-orange-600 hover:bg-orange-500'}`}
                    >
                        {executeStatus === 'signing' ? '✍️ Firmando...' :
                            executeStatus === 'relaying' ? '🚀 Ejecutando...' :
                                executeStatus === 'success' ? '✅ Ejecutada!' :
                                    executeStatus === 'error' ? '❌ Error' :
                                        (isExpired && p.votesFor <= p.votesAgainst) ? 'Rechazada' :
                                            'Ejecutar Propuesta'}
                    </button>

                    {executeStatus === 'error' && errorMessage && <p className="text-center text-xs mt-1 text-red-500">{errorMessage}</p>}
                </div>
            )}
        </div>
    );
}

function StatusBadge({ executed, expired }: any) {
    if (executed) return <span className="bg-green-900 text-green-300 px-2 py-0.5 rounded text-xs font-bold ring-1 ring-green-500/50">EXECUTED</span>;
    if (expired) return <span className="bg-red-900 text-red-300 px-2 py-0.5 rounded text-xs font-bold ring-1 ring-red-500/50">EXPIRED</span>;
    return <span className="bg-blue-900 text-blue-300 px-2 py-0.5 rounded text-xs font-bold animate-pulse ring-1 ring-blue-500/50">ACTIVE</span>;
}

function VoteBar({ label, count, total, color }: any) {
    const c = Number(count);
    const t = Number(total);
    const percentage = t > 0 ? (c / t) * 100 : 0;

    return (
        <div className="flex items-center gap-2 text-xs">
            <span className="w-16 text-slate-400 font-medium">{label}</span>
            <div className="flex-1 h-2 bg-slate-700 rounded-full overflow-hidden relative">
                <div
                    className={`h-full ${color} transition-all duration-500 ease-out`}
                    style={{ width: `${percentage}%` }}
                ></div>
            </div>
            <span className="w-8 text-right text-slate-300 font-mono">{c}</span>
        </div>
    );
}
