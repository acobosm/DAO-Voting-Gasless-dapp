'use client';

import { useReadContract, useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import { DAO_VOTING_CONFIG } from '../lib/config';
import { useState, useEffect } from 'react';
import DAOVotingABI from '../lib/abi/DAOVoting.json';

export default function DAOStats() {
    const { address } = useAccount();
    const [depositAmount, setDepositAmount] = useState('');
    const [isClient, setIsClient] = useState(false);

    useEffect(() => {
        setIsClient(true);
    }, []);

    const { data: totalBalance, refetch: refetchTotal } = useReadContract({
        ...DAO_VOTING_CONFIG,
        functionName: 'getTotalDaoBalance',
        query: { refetchInterval: 5000 }
    });

    const { data: userBalance, refetch: refetchUser } = useReadContract({
        ...DAO_VOTING_CONFIG,
        functionName: 'getUserBalance',
        args: address ? [address] : undefined,
        query: { enabled: !!address, refetchInterval: 5000 }
    });

    const { writeContract, data: hash, isPending, error } = useWriteContract();

    const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

    useEffect(() => {
        if (isConfirmed) {
            setDepositAmount('');
            refetchTotal();
            refetchUser();
        }
    }, [isConfirmed]);

    const handleDeposit = () => {
        if (!depositAmount) return;
        try {
            writeContract({
                address: DAO_VOTING_CONFIG.address,
                abi: DAOVotingABI.abi,
                functionName: 'fundDao',
                value: parseEther(depositAmount),
            });
        } catch (err) {
            console.error(err);
        }
    };

    if (!isClient) return <div className="p-4 bg-slate-800 text-slate-400">Cargando datos...</div>;

    return (
        <div className="flex flex-col gap-6">
            <div className="grid grid-cols-2 gap-4">
                {/* Treasury Card */}
                <div className="bg-slate-950 p-4 rounded border border-slate-800">
                    <p className="text-xs text-slate-500 uppercase font-bold">Tesorería Total</p>
                    <p className="text-2xl font-bold text-blue-400">
                        {totalBalance ? formatEther(totalBalance as bigint) : '0.0'} ETH
                    </p>
                </div>

                {/* User Balance Card */}
                <div className="bg-slate-950 p-4 rounded border border-slate-800">
                    <p className="text-xs text-slate-500 uppercase font-bold">Mi Saldo</p>
                    <p className="text-2xl font-bold text-purple-400">
                        {userBalance ? formatEther(userBalance as bigint) : '0.0'} ETH
                    </p>
                </div>
            </div>

            {/* Deposit Form */}
            <div className="bg-slate-950 p-4 rounded border border-slate-800">
                <p className="text-sm font-bold text-white mb-2">Depositar Fondos a la DAO</p>
                <div className="flex gap-2">
                    <input
                        type="number"
                        className="flex-1 bg-black border border-slate-700 p-2 text-white rounded"
                        placeholder="0.0 ETH"
                        value={depositAmount}
                        onChange={(e) => setDepositAmount(e.target.value)}
                    />
                    <button
                        onClick={handleDeposit}
                        disabled={isPending || !depositAmount}
                        className="bg-blue-600 text-white font-bold px-4 py-2 rounded hover:bg-blue-500 disabled:opacity-50"
                    >
                        {isPending ? '...' : 'Depositar'}
                    </button>
                </div>
                {isConfirmed && <p className="text-green-500 text-sm mt-2 font-bold">✅ Depósito confirmado</p>}
                {error && <p className="text-red-500 text-sm mt-2">{error.message.split('.')[0]}</p>}
            </div>
        </div>
    );
}
