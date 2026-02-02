import { NextRequest, NextResponse } from 'next/server';
import { createWalletClient, http, createPublicClient, recoverTypedDataAddress } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { anvil } from 'viem/chains';
import { FORWARDER_CONFIG, ANVIL_CHAIN_ID } from '../../../lib/config';
import { ForwardRequest, SIGNING_DOMAIN_NAME, SIGNING_DOMAIN_VERSION } from '../../../lib/types';

// ----------------------------------------------------------------------
// CONFIGURACIÓN DEL RELAYER
// ----------------------------------------------------------------------
// Usamos la LLAVE PRIVADA #1 de Anvil (NO la #0 que suele ser el deployer)
// para simular que es un tercero quien paga el gas.
const RELAYER_PRIVATE_KEY = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';
const account = privateKeyToAccount(RELAYER_PRIVATE_KEY);

const client = createWalletClient({
    account,
    chain: anvil,
    transport: http(),
});

const publicClient = createPublicClient({
    chain: anvil,
    transport: http(),
});

export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const { request, signature } = body;

        console.log("📨 Relayer received request:", request);
        console.log("✍️  Signature:", signature);

        // 1. Validar inputs básicos
        if (!request || !signature) {
            return NextResponse.json({ error: 'Missing request or signature' }, { status: 400 });
        }

        // Reconstruct request with BigInts for Viem
        const typedRequest = {
            ...request,
            value: BigInt(request.value),
            gas: BigInt(request.gas),
            nonce: BigInt(request.nonce)
        };

        // --- DEBUG: OFF-CHAIN RECOVERY ---
        try {
            const domain = {
                name: SIGNING_DOMAIN_NAME,
                version: SIGNING_DOMAIN_VERSION,
                chainId: BigInt(ANVIL_CHAIN_ID),
                verifyingContract: FORWARDER_CONFIG.address,
            } as const;

            const types = {
                ForwardRequest,
            } as const;

            const recoveredAddress = await recoverTypedDataAddress({
                domain,
                types,
                primaryType: 'ForwardRequest',
                message: typedRequest,
                signature,
            });

            console.log("🔍 DEBUG Recovery:");
            console.log("   Expected Signer (from):", typedRequest.from);
            console.log("   Recovered Signer:", recoveredAddress);
            console.log("   Domain:", JSON.stringify(domain, (key, value) => typeof value === 'bigint' ? value.toString() : value));

            if (recoveredAddress.toLowerCase() !== typedRequest.from.toLowerCase()) {
                console.error("❌ Mismatch detected off-chain! The signature does not match the provided parameters.");
            } else {
                console.log("✅ Off-chain recovery SUCCESS. Signature is valid for these parameters.");
            }

        } catch (debugErr) {
            console.error("⚠️ Debug recovery failed:", debugErr);
        }
        // ---------------------------------

        // 2. Verificar la transacción en el Forwarder antes de enviarla (Simulación)
        // Esto ahorra gas si la tx va a fallar.

        try {
            const valid = await publicClient.readContract({
                ...FORWARDER_CONFIG,
                functionName: 'verify',
                args: [typedRequest, signature],
            });

            if (!valid) {
                console.error("❌ Signature verification failed on-chain");
                return NextResponse.json({ error: 'Invalid signature or request' }, { status: 400 });
            }
        } catch (err) {
            console.error("❌ Error verifying request:", err);
            // Attempt to debug by recovering address manually if possible, or just log more details
            return NextResponse.json({ error: 'Verification reverted', details: (err as any).toString() }, { status: 400 });
        }

        // 3. Ejecutar la transacción (Pagar el GAS)
        console.log("🚀 Relayer submitting transaction...");
        const hash = await client.writeContract({
            ...FORWARDER_CONFIG,
            functionName: 'execute',
            args: [typedRequest, signature],
        });

        console.log("✅ Transaction sent! Hash:", hash);

        return NextResponse.json({ success: true, txHash: hash });

    } catch (error: any) {
        console.error("💥 Relayer Error:", error);
        return NextResponse.json({
            error: 'Relayer failed',
            details: error.message || error.toString()
        }, { status: 500 });
    }
}
