# Guía Técnica para Video Explicativo: DAO Voting App

Este documento detalla los aspectos técnicos de la aplicación DAO Voting.
---

## Tecnologías Utilizadas

A continuación, se describen las tecnologías clave empleadas en el desarrollo de esta DApp:

### BackEnd (Smart Contracts)
*   **Solidity:** Lenguaje de programación para los contratos inteligentes.
*   **Foundry:** Entorno de desarrollo para compilación, despliegue y testing.

### FrontEnd
*   **Next.js:** Framework de React para la aplicación web.
*   **Wagmi:** Hooks y utilidades para interactuar con Ethereum.
*   **Viem:** Librería de bajo nivel para interfaces de Ethereum (backend de Wagmi).
*   **TailwindCSS:** Framework de estilos utilitarios.
*   **TypeScript:** Superset tipado de JavaScript.

## 1. Conexión de Usuario
*   **Funcionalidad:** Conexión y desconexión de la wallet (MetaMask, etc.).
*   **Componente Frontend:** `web/components/ConnectButton.tsx`
*   **Detalle:** Implementación propia utilizando los hooks de **Wagmi** (`useConnect`, `useDisconnect` y `useAccount`). Se emplea el conector `injected()` para establecer la comunicación directa con la billetera del navegador (MetaMask), gestionando el estado de la conexión y mostrando la dirección del usuario manualmente, sin depender de librerías de UI externas.

## 2. Depositar Saldo (Financiar la DAO)
*   **Función Smart Contract:** `fundDao()`
*   **Archivo:** `sc/src/DAOVoting.sol`
*   **Lógica:** Recibe ETH (`payable`), lo suma al balance interno del usuario (`_userBalances`) y al total de la DAO (`_totalDaoBalance`). Emite el evento `FundsDeposited`.

## 3. Verificación de Saldos
*   **Saldo de la DAO:**
    *   **Función SC:** `getTotalDaoBalance()`
    *   **Archivo:** `sc/src/DAOVoting.sol`
*   **Saldo del Usuario (Depositado):**
    *   **Función SC:** `getUserBalance(address user)`
    *   **Archivo:** `sc/src/DAOVoting.sol`
*   **Frontend:** Estos datos se leen usando el hook `useReadContract` de wagmi en `web/components/DAOStats.tsx`.

## 4. Crear Propuesta: Verificación del 10%
*   **Función Smart Contract:** `createProposal(...)`
*   **Validación (Modifier):** `onlyProposer` (que llama a `_onlyProposer`).
*   **Archivo:** `sc/src/DAOVoting.sol`
*   **Lógica:** Verifica matemáticamente:
    ```solidity
    uint256 requiredBalance = (_totalDaoBalance * 10) / 100;
    require(_userBalances[sender] >= requiredBalance, "...");
    ```
*   **Frontend (Manejo de Error):**
    *   **Archivo:** `web/components/ProposalForm.tsx`
    *   **Lógica:** En la función `handleGaslessSubmit`, capturamos el error del contrato. Si es "Insufficient balance", consultamos el saldo del usuario para mostrar el mensaje específico (si tiene 0 o si tiene menos del 10%).

## 5. Almacenamiento de Propuestas
*   **Ubicación:** Blockchain (Smart Contract).
*   **Variable de Estado:** `mapping(uint256 => Proposal) public proposals`
*   **Tipo de Dato (`struct Proposal`):**
    *   `id` (uint256)
    *   `description` (string) - *Guardado en cadena*
    *   `recipient` (address)
    *   `amount` (uint256)
    *   `deadline` (uint256)
    *   `votesFor`, `votesAgainst`, `votesAbstain` (uint256)
    *   `state` (enum)
    *   `executed` (bool)

## 6. Fecha Límite (Deadline)
*   **Almacenamiento:** En el struct `Proposal`, campo `deadline`.
*   **Tipo:** `uint256` (Timestamp Unix en segundos).
*   **Validación en Creación:** `require(deadline > block.timestamp, ...)` en `createProposal`.

## 7. Derecho al Voto
*   **Verificación:** ¿Quién puede votar?
*   **Función SC:** `vote(...)`
*   **Archivo:** `sc/src/DAOVoting.sol`
*   **Lógica:**
    ```solidity
    require(_userBalances[voter] > 0, "DAOVoting: User must have a deposited balance to vote.");
    ```
    Solo usuarios con saldo depositado (> 0) pueden votar.

## 8. Almacenamiento de Votos
*   **Variable:** `mapping(uint256 => mapping(address => VoteType)) private _userVotes`
*   **Tipo de Dato:** `enum VoteType` (`NONE`, `ABSTAIN`, `FOR`, `AGAINST`).
*   **Contadores:** Se almacenan como enteros (`uint256`) dentro de cada `Proposal`.

## 9. Cambio de Voto y Verificación de "Ya votó"
*   **Función SC:** `vote(...)`
*   **Archivo:** `sc/src/DAOVoting.sol`
*   **Lógica:**
    1.  El contrato consulta `_userVotes[proposalId][sender]`.
    2.  Si es diferente de `NONE`, significa que ya votó.
    3.  Resta el voto anterior de los contadores (`votesFor--`, etc.).
    4.  Suma el nuevo voto (`votesFor++`).
    5.  Actualiza el mapeo `_userVotes`.

## 10. Verificación del Vencimiento (Deadline)
*   **Para Votar:** En `vote()`, se verifica `require(block.timestamp <= proposal.deadline, "Voting deadline passed")`.
*   **Para Ejecutar:** En `executeProposal()`, se verifica `require(block.timestamp > proposal.deadline, "Voting is still active")`.

## 11. Ejecución de la Propuesta
*   **Función SC:** `executeProposal(uint256 proposalId)`
*   **Archivo:** `sc/src/DAOVoting.sol`
*   **Lógica:**
    1.  Verifica que pasó el deadline.
    2.  Verifica que no se haya ejecutado ya.
    3.  Comprueba si `votesFor > votesAgainst`.
    4.  Si gana: Cambia estado a `Executed`, resta fondos del balance total y envia ETH (`call{value:...}`).

## 12. Auto-Rechazo (Lógica Pasiva)
*   **Ubicación:** `executeProposal` (Smart Contract) y `ProposalList.tsx` (Frontend visual).
*   **Lógica:** No hay una función "rechazar". Simplemente, cuando alguien llama a `executeProposal`, si la condición `votesFor > votesAgainst` NO se cumple, entra al bloque `else`:
    ```solidity
    else {
        proposal.state = ProposalState.Rejected;
        proposal.executed = true;
    }
    ```
    Esto marca la propuesta como finalizada y rechazada, sin transferir fondos. Visualmente, el Frontend lo muestra como "Rechazada" automáticamente al comparar los votos una vez expirado el tiempo.
