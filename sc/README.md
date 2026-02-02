## Funciones de DAOVoting.sol

Este es un listado de todas las funciones que componen el smart contract **DAOVoting.sol**

Están divididas por su tipo en función de cuáles requieren cast send (cambian el estado/consumen gas) y cuáles cast call (solo lectura)

## 1. Funciones de Escritura (cast send)

Estas son las que ejecutan acciones y mueven el estado de la blockchain.

### fundDao():
Permite a los usuarios depositar Ether y ganar poder de voto.

### createProposal(address recipient, uint256 amount, uint256 deadline):
Registra una nueva intención de gasto.

### vote(uint256 proposalId, VoteType voteType):
Registra tu voto (FOR, AGAINST, ABSTAIN).

### executeProposal(uint256 proposalId):
Realiza la transferencia de fondos si se cumplen las condiciones.

### withdrawFunds(uint256 amount):
(Aún no incluida en el código) Permite a un socio retirar su capital depositado, siempre y cuando no esté comprometido en una propuesta activa.

## 2. Funciones de Lectura (cast call)

Estas son para auditoría y visualización de datos. Son las que usarás para alimentar la información que se verá en el Frontend.

### getProposal(uint256 proposalId):
Devuelve todos los datos de una propuesta (el ID, el beneficiario, los votos, etc.).

### getUserBalance(address user):
Consulta cuánto Ether tiene depositado un usuario específico en la DAO.

### getTotalDaoBalance():
Consulta el dinero total acumulado en el contrato.

### hasVoted(uint256 proposalId, address user):
Devuelve un true/false para saber si alguien ya participó en una votación.

### getProposalState(uint256 proposalId):
Una función rápida para saber si está Active, Approved, etc.