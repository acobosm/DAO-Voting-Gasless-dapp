# DAO Voting Application

Esta es una Aplicación Descentralizada (DApp) de gobernanza que permite a los miembros de una DAO proponer, votar y ejecutar decisiones financieras de manera transparente en la blockchain de Ethereum.

## 1. Instrucciones de instalación

Para poner en marcha el proyecto localmente, sigue estos pasos:

### Requisitos previos
- [Node.js](https://nodejs.org/) (v18 o superior)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (para los Smart Contracts)
- [MetaMask](https://metamask.io/) o cualquier wallet compatible con EIP-1193.

### Pasos de Instalación

> [!NOTE]
> Si deseas utilizar esta aplicación, puedes descargarla o clonarla desde GitHub en la siguiente dirección: `https://github.com/acobosm/DAO-Voting-Gasless-dapp.git`. 

1.  **Clonar el repositorio:**
    ```bash
    git clone <url-del-repositorio>
    cd "02 DAO Voting"
    ```

2.  **Configurar Smart Contracts:**
    ```bash
    cd sc
    forge install
    forge build
    ```

3.  **Configurar Frontend:**
    ```bash
    cd ../web
    npm install
    # o si prefieres pnpm
    pnpm install
    ```

---

## 2. Comandos para deployment

### Smart Contracts (Foundry)

Para desplegar los contratos inteligentes, utiliza el script proporcionado. Asegúrate de tener configurada tu clave privada y la URL del RPC.

```bash
cd sc
forge script script/DeployDAO.s.sol:DeployDAO --rpc-url <TU_RPC_URL> --private-key <TU_PRIVATE_KEY> --broadcast
```

> [!TIP]
> Puedes usar redes de prueba como Sepolia o redes locales como Anvil (`anvil` para iniciar el nodo y luego desplegar).

### Frontend (Next.js)

Una vez desplegado el contrato, asegúrate de actualizar la dirección del contrato en la configuración del frontend (usualmente en `web/lib/constants.ts` o archivos de configuración similares) y luego construye la aplicación:

```bash
cd web
npm run build
# Para iniciar en modo producción
npm run start
# Para desarrollo local
npm run dev
```

---

## 3. Guía de uso de la aplicación

1.  **Conexión de Wallet:** Haz clic en el botón "Connect Wallet" para vincular tu cuenta de MetaMask.
2.  **Financiar la DAO:** Dirígete a la sección de depósito y envía ETH a la DAO para obtener poder de voto.
3.  **Panel de Estadísticas:** Visualiza el balance total de la DAO y tu saldo depositado.
4.  **Crear una Propuesta:**
    - Ingresa la dirección del beneficiario, el monto y la fecha límite.
    - **Importante:** Necesitas tener depositado al menos el 10% del balance total de la DAO para crear una propuesta.
5.  **Votación:**
    - Selecciona una propuesta activa.
    - Elige tu voto: **A favor**, **En contra** o **Abstención**.
    - Tu poder de voto es proporcional a tu saldo depositado.
6.  **Ejecución:**
    - Una vez finalizado el plazo (deadline), cualquiera puede solicitar la ejecución.
    - Si la propuesta es aprobada (Votos a favor > Votos en contra), los fondos se transferirán automáticamente al beneficiario.

---

## 4. Arquitectura del proyecto

El proyecto está dividido en dos grandes bloques:

### Backend (Carpeta `sc/`)
Desarrollado con **Solidity** y gestionado con **Foundry**.
- `src/DAOVoting.sol`: Contrato principal que gestiona la lógica de propuestas, votos y tesorería.
- `script/DeployDAO.s.sol`: Script de automatización para el despliegue.
- `test/`: Suite de pruebas unitarias para garantizar la seguridad del contrato.
- `foundry.toml`: Configuración del entorno de desarrollo Foundry.

### Frontend (Carpeta `web/`)
Desarrollado con **Next.js** y **TypeScript**.
- `app/`: Contiene las páginas y el layout principal de la aplicación.
- `components/`: Componentes modulares de React (ConnectButton, ProposalForm, ProposalList, etc.).
- `lib/`: Configuraciones de **Wagmi** y **Viem** para la interacción con la blockchain.
- `public/`: Assets estáticos.
- `tailwind.config.mjs`: Configuración de estilos utilizando **TailwindCSS**.

---

## 5. Testeos

ebit@DESKTOP-QKHOJLB:~/projects/0 CodeCrypto Academy/03 Ethereum Practice/Intro a Proyectos de Entrenamiento/Proyectos obligatorios/02 DAO Voting/sc$ forge coverage --ir-minimum
Warning: `--ir-minimum` enables `viaIR` with minimum optimization, which can result in inaccurate source mappings.
Only use this flag as a workaround if you are experiencing "stack too deep" errors.
Note that `viaIR` is production ready since Solidity 0.8.13 and above.
See more: https://github.com/foundry-rs/foundry/issues/3357
[⠊] Compiling...
[⠒] Compiling 35 files with Solc 0.8.33
[⠑] Solc 0.8.33 finished in 1.52s
Compiler run successful with warnings:
Warning (4591): There are more than 256 warnings. Ignoring the rest.
Analysing contracts...
Running tests...

Ran 8 tests for test/DAOVoting.t.sol:DAOVotingTest
[PASS] testWithdraw() (gas: 45465)
[PASS] test_ExecuteProposal_Fail_RejectedAndTiming() (gas: 308563)
[PASS] test_ExecuteProposal_Success_Approved() (gas: 315341)
[PASS] test_Propose_Fail_InsufficientBalance() (gas: 19248)
[PASS] test_Propose_Success() (gas: 169728)
[PASS] test_VoteGasless_Fail_InvalidNonce() (gas: 268909)
[PASS] test_VoteGasless_Success() (gas: 268832)
[PASS] test_Vote_Fail_InvalidTypeNone() (gas: 162687)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 7.00ms (15.83ms CPU time)

Ran 1 test suite in 10.57ms (7.00ms CPU time): 8 tests passed, 0 failed, 0 skipped (8 total tests)

╭--------------------------+-----------------+-----------------+---------------+-----------------╮
| File                     | % Lines         | % Statements    | % Branches    | % Funcs         |
+================================================================================================+
| script/DeployDAO.s.sol   | 0.00% (0/9)     | 0.00% (0/10)    | 100.00% (0/0) | 0.00% (0/1)     |
|--------------------------+-----------------+-----------------+---------------+-----------------|
| src/DAOVoting.sol        | 88.16% (67/76)  | 87.50% (63/72)  | 11.76% (6/51) | 100.00% (11/11) |
|--------------------------+-----------------+-----------------+---------------+-----------------|
| src/MinimalForwarder.sol | 86.67% (26/30)  | 87.10% (27/31)  | 16.67% (1/6)  | 100.00% (7/7)   |
|--------------------------+-----------------+-----------------+---------------+-----------------|
| Total                    | 80.87% (93/115) | 79.65% (90/113) | 12.28% (7/57) | 94.74% (18/19)  |
╰--------------------------+-----------------+-----------------+---------------+-----------------╯

ebit@DESKTOP-QKHOJLB:~/projects/0 CodeCrypto Academy/03 Ethereum Practice/Intro a Proyectos de Entrenamiento/Proyectos obligatorios/02 DAO Voting/sc$ forge test -vvv
[⠊] Compiling...
No files changed, compilation skipped

Ran 8 tests for test/DAOVoting.t.sol:DAOVotingTest
[PASS] testWithdraw() (gas: 38270)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_ExecuteProposal_Fail_RejectedAndTiming() (gas: 266874)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_ExecuteProposal_Success_Approved() (gas: 274879)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_Propose_Fail_InsufficientBalance() (gas: 14713)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_Propose_Success() (gas: 151656)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_VoteGasless_Fail_InvalidNonce() (gas: 237844)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_VoteGasless_Success() (gas: 236139)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

[PASS] test_Vote_Fail_InvalidTypeNone() (gas: 150021)
Logs:
  FORWARDER_ADDRESS:  0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  DAO_VOTING_ADDRESS:  0x2e234DAe75C793f67A35089C9d99245E1C58470b

Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 12.34ms (21.61ms CPU time)

Ran 1 test suite in 69.73ms (12.34ms CPU time): 8 tests passed, 0 failed, 0 skipped (8 total tests)

---

Desarrollado como proyecto para la Maestría Ingeniero BlockChain 360 de CodeCrypto Academy.
