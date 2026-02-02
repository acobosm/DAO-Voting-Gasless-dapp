// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC2771Context
} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";  // ******* LINEA A SER ELIMINADA *******

/**
 * @title DAOVoting
 * @notice Contrato principal de la DAO que gestiona propuestas y votación gasless.
 * Hereda de ERC2771Context para reconocer las meta-transacciones.
 */
contract DAOVoting is ERC2771Context {
    using SafeERC20 for address;

    // ====================================================================
    // 1. ESTRUCTURAS Y ENUMERACIONES
    // ====================================================================

    // Define los tipos de voto permitidos [cite: 28]
    enum VoteType {
        NONE, // Usuario no ha votado aun
        ABSTAIN, // Abstención
        FOR, // A Favor
        AGAINST // En Contra
    }

    // Define el estado de la propuesta [cite: 24, 103]
    enum ProposalState {
        Active,
        Approved,
        Rejected,
        Executed
    }

    // Estructura para almacenar los datos de cada propuesta [cite: 18-24]
    struct Proposal {
        uint256 id; // ID secuencial [cite: 19]
        string description; // Descripción de la propuesta
        address recipient; // Dirección del beneficiario [cite: 21]
        uint256 amount; // Monto en ETH a transferir [cite: 20]
        uint256 deadline; // Fecha límite de votación (timestamp) [cite: 22]
        uint256 votesFor; // Contadores de votos a favor [cite: 23]
        uint256 votesAgainst; // Contadores de votos en contra [cite: 23]
        uint256 votesAbstain; // Contadores de abstenciones [cite: 23]
        ProposalState state; // Estado actual [cite: 24]
        bool executed; // Si ya ha sido ejecutada [cite: 24]
    }

    // ====================================================================
    // 2. ESTADO DEL CONTRATO
    // ====================================================================

    // Mapeo de la lista de propuestas (ID => Proposal)
    mapping(uint256 => Proposal) public proposals;
    uint256 public nextProposalId = 1;

    // Mapeo del balance de fondeo de cada usuario (dirección => cantidad de ETH depositada)
    mapping(address => uint256) private _userBalances;
    uint256 private _totalDaoBalance;

    // Mapeo del voto de un usuario por propuesta (Proposal ID => User Address => VoteType)
    mapping(uint256 => mapping(address => VoteType)) private _userVotes;

    // Eventos (Mejor práctica para la trazabilidad y el frontend)
    event FundsDeposited(
        address indexed user,
        uint256 amount,
        uint256 newTotalBalance
    );
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed creator,
        string description,
        address recipient,
        uint256 amount,
        uint256 deadline
    );

    event ProposalExecuted(uint256 indexed proposalId, ProposalState state);

    // ====================================================================
    // 3. CONSTRUCTOR
    // ====================================================================

    /**
     * @notice Constructor para inicializar el contrato.
     * @param trustedForwarder La dirección del MinimalForwarder confiable (EIP-2771).
     */
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}

    // ====================================================================
    // 4. GESTIÓN DE FONDOS
    // ====================================================================

    /**
     * @notice Permite a los usuarios depositar ETH para financiar el DAO. [cite: 35]
     * @dev El balance total del DAO se utiliza para calcular el umbral de creación de propuestas. [cite: 36, 38]
     */
    function fundDao() external payable {
        require(msg.value > 0, "DAOVoting: Amount must be greater than zero");

        address sender = _msgSender(); // Obtiene el remitente real (funciona con meta-transacciones)

        _userBalances[sender] += msg.value;
        _totalDaoBalance += msg.value;

        emit FundsDeposited(sender, msg.value, _totalDaoBalance);
    }

    /**
     * @notice Retorna el balance de ETH que un usuario ha depositado en el DAO. [cite: 45]
     * @param user Dirección del usuario.
     * @return uint256 Balance del usuario.
     */
    function getUserBalance(address user) external view returns (uint256) {
        return _userBalances[user];
    }

    /**
     * @notice Retorna el balance total de ETH del DAO (suma de todos los depósitos).
     */
    function getTotalDaoBalance() external view returns (uint256) {
        return _totalDaoBalance;
    }

    // ====================================================================
    // 5. MODIFICADORES
    // ====================================================================

    /**
     * @notice Requiere que el remitente tenga al menos el 10% del balance total del DAO.
     */
    modifier onlyProposer() {
        // Obtenemos el remitente real (funciona con meta-transacciones)
        // address sender = _msgSender();  // ******* LINEA A SER ELIMINADA *******

        // Requerimos que el balance del usuario sea mayor o igual al 10% del balance total del DAO
        // Cálculo: (Balance Total * 10) / 100
        // Usamos SafeMath de Solidity (implícito desde 0.8.0) para prevenir overflows.
        // Aunque el balance total podría ser cero, verificamos si es mayor a cero para evitar división entre cero,
        // pero el chequeo principal es si el balance del usuario es >= al umbral.
        // require(_totalDaoBalance > 0, "DAOVoting: DAO has no funds yet.");  // ******* LINEA A SER ELIMINADA *******

        // Calcula el umbral de 10%
        // uint256 requiredBalance = (_totalDaoBalance * 10) / 100;   // ******* LINEA A SER ELIMINADA *******

        // Valida que el balance del usuario cumpla con el requisito
        /* require(    // ******* BLOQUE A SER ELIMINADO *******
            _userBalances[sender] >= requiredBalance,
            "DAOVoting: Insufficient balance. Must hold >= 10% of total DAO balance to propose."
        );*/
        _onlyProposer(); // Llama a la función de validación
        _;
    }

    // Nueva función interna con la lógica de validación
    function _onlyProposer() internal view {
        // Nota: Es 'view' si solo lee estados y no los modifica
        address sender = _msgSender();

        require(_totalDaoBalance > 0, "DAOVoting: DAO has no funds yet.");

        // Calcula el umbral de 10%
        uint256 requiredBalance = (_totalDaoBalance * 10) / 100;

        // Valida que el balance del usuario cumpla con el requisito
        require(
            _userBalances[sender] >= requiredBalance,
            "DAOVoting: Insufficient balance. Must hold >= 10% of total DAO balance to propose."
        );
    }

    // ====================================================================
    // 6. CREACIÓN DE PROPUESTAS
    // ====================================================================

    /**
     * @notice Permite a un usuario con el balance suficiente crear una nueva propuesta.
     * @param recipient Dirección a donde se enviarán los fondos. [cite: 21]
     * @param amount Cantidad de ETH a transferir. [cite: 20]
     * @param deadline Fecha límite de votación (timestamp). [cite: 22]
     */
    function createProposal(
        string memory description,
        address recipient,
        uint256 amount,
        uint256 deadline
    ) external onlyProposer {
        require(
            recipient != address(0),
            "DAOVoting: Invalid recipient address."
        );
        require(
            amount > 0,
            "DAOVoting: Proposal amount must be greater than zero."
        );
        // El monto debe ser menor que el balance total para asegurar que no se vacíe el DAO completamente
        require(
            amount <= address(this).balance,
            "DAOVoting: Proposal amount exceeds DAO's current ETH balance."
        );
        require(
            deadline > block.timestamp,
            "DAOVoting: Deadline must be in the future."
        );

        // Obtenemos el remitente real
        address creator = _msgSender();
        uint256 proposalId = nextProposalId;

        // Crear la nueva propuesta
        proposals[proposalId] = Proposal({
            id: proposalId,
            description: description,
            recipient: recipient,
            amount: amount,
            deadline: deadline,
            votesFor: 0,
            votesAgainst: 0,
            votesAbstain: 0,
            state: ProposalState.Active, // Inicia activa
            executed: false
        });

        // Incrementamos el contador para la siguiente propuesta
        nextProposalId++;

        // Emitir evento
        emit ProposalCreated(
            proposalId,
            creator,
            description,
            recipient,
            amount,
            deadline
        );
    }

    // ====================================================================
    // 7. CONSULTAS (GETTERS)
    // ====================================================================

    /**
     * @notice Retorna los detalles de una propuesta. [cite: 44]
     * @param proposalId ID de la propuesta.
     * @return Proposal Struct.
     */
    function getProposal(
        uint256 proposalId
    ) external view returns (Proposal memory) {
        require(
            proposalId > 0 && proposalId < nextProposalId,
            "DAOVoting: Proposal does not exist."
        );
        return proposals[proposalId];
    }

    // ====================================================================
    // 8. VOTO DE PROPUESTAS
    // ====================================================================

    /**
     * @notice Permite a un usuario votar o cambiar su voto en una propuesta.
     * @dev Esta función es diseñada para ser llamada vía meta-transacción (gasless).
     * @param proposalId ID de la propuesta.
     * @param voteType Tipo de voto (FOR, AGAINST, ABSTAIN).
     */
    function vote(uint256 proposalId, VoteType voteType) external {
        address voter = _msgSender(); // Remitente real (usuario)
        Proposal storage proposal = proposals[proposalId];

        // 1. Validaciones

        // Nueva validación: Evita que el usuario envíe el valor 0 (NONE)
        require(voteType != VoteType.NONE, "DAOVoting: Invalid vote type.");

        require(
            proposal.state == ProposalState.Active,
            "DAOVoting: Proposal not active."
        );
        require(
            block.timestamp <= proposal.deadline,
            "DAOVoting: Voting deadline passed."
        );

        // Requisito: balance mínimo para votar
        // Por simplicidad, requeriremos que el usuario tenga cualquier balance (> 0) para votar.
        require(
            _userBalances[voter] > 0,
            "DAOVoting: User must have a deposited balance to vote."
        );

        // 2. Manejo de cambio de voto
        VoteType previousVote = _userVotes[proposalId][voter];

        // Si el voto anterior NO es NONE, significa que ya votó y debemos restar
        if (previousVote != VoteType.NONE) {
            if (previousVote == VoteType.FOR) {
                proposal.votesFor--;
            } else if (previousVote == VoteType.AGAINST) {
                proposal.votesAgainst--;
            } else if (previousVote == VoteType.ABSTAIN) {
                proposal.votesAbstain--;
            }
        }

        // 3. Registrar y aplicar el nuevo voto
        _userVotes[proposalId][voter] = voteType;

        if (voteType == VoteType.FOR) {
            proposal.votesFor++;
        } else if (voteType == VoteType.AGAINST) {
            proposal.votesAgainst++;
        } else if (voteType == VoteType.ABSTAIN) {
            proposal.votesAbstain++;
        }
        // Importante: No hay lógica para VoteType.NONE aquí porque un usuario
        // no debería poder "des-votar" a un estado nulo una vez que participó.

        // Opcionalmente, emitir un evento de voto
        // emit VoteCasted(proposalId, voter, voteType);
    }

    /**
     * @notice Ejecuta una propuesta si el tiempo ha terminado y la votación fue exitosa (FOR > AGAINST).
     * @param proposalId ID de la propuesta a ejecutar.
     */
    /* function executeProposal(uint256 proposalId) public {
        // Usamos 'storage' para modificar la estructura en el almacenamiento
        Proposal storage proposal = proposals[proposalId];

        // 1. Verificaciones iniciales
        require(proposal.id != 0, "DAOVoting: Proposal does not exist.");
        require(!proposal.executed, "DAOVoting: Proposal already executed.");

        // 2. Verificar que el deadline ha pasado (requerido por el sistema de ejecución)
        require(
            block.timestamp > proposal.deadline,
            "DAOVoting: Voting is still active."
        );

        // 3. Determinar el estado final y ejecutar
        if (proposal.votesFor > proposal.votesAgainst) {
            // Propuesta APROBADA
            proposal.state = ProposalState.Executed;
            proposal.executed = true;

            // Actualizamos la contabilidad interna
            _totalDaoBalance -= proposal.amount;

            // Transferencia de fondos (la ejecución principal de la DAO)
            (bool success, ) = proposal.recipient.call{value: proposal.amount}(
                ""
            );
            require(success, "DAOVoting: ETH transfer failed.");
        } else {
            // Propuesta RECHAZADA (FOR <= AGAINST)
            proposal.state = ProposalState.Rejected;
            proposal.executed = true; // Marcamos como ejecutada para que no se reintente
        }

        emit ProposalExecuted(proposalId, proposal.state);
    }*/

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        // 1. CHECKS (Verificaciones)
        require(proposal.id != 0, "DAOVoting: Proposal does not exist.");
        require(!proposal.executed, "DAOVoting: Proposal already executed.");
        require(
            block.timestamp > proposal.deadline,
            "DAOVoting: Voting is still active."
        );

        // NUEVA VERIFICACIÓN DE INFRAESTRUCTURA:
        // Evita que la función intente ejecutarse si físicamente no hay dinero en el contrato
        require(
            address(this).balance >= proposal.amount,
            "DAOVoting: Insufficient contract balance."
        );

        // 2. EFFECTS (Cambios de estado internos)
        if (proposal.votesFor > proposal.votesAgainst) {
            proposal.state = ProposalState.Executed;
            proposal.executed = true;

            // Primero restamos de la contabilidad para prevenir ataques de reentrada
            _totalDaoBalance -= proposal.amount;

            // 3. INTERACTIONS (Envío de fondos al exterior)
            (bool success, ) = proposal.recipient.call{value: proposal.amount}(
                ""
            );
            require(success, "DAOVoting: ETH transfer failed.");
        } else {
            proposal.state = ProposalState.Rejected;
            proposal.executed = true;
        }

        emit ProposalExecuted(proposalId, proposal.state);
    }

    // ====================================================================
    // 9. RETIRO DE FONDOS DE LA DAO
    // ====================================================================
    /**
     * @notice Permite a un usuario retirar todo su capital depositado.
     */
    function withdraw() external {
        uint256 amount = _userBalances[msg.sender];

        require(amount > 0, "DAOVoting: No balance to withdraw");

        // IMPORTANTE: Primero actualizamos el estado para evitar reentrancia
        _userBalances[msg.sender] = 0;
        _totalDaoBalance -= amount;

        // Luego enviamos el dinero
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "DAOVoting: Transfer failed");
    }

    // ====================================================================
    // 10. CONSULTA DE VOTO
    // ====================================================================

    /**
     * @notice Retorna el tipo de voto de un usuario en una propuesta específica.
     * @param proposalId ID de la propuesta.
     * @param user Dirección del usuario.
     * @return VoteType El voto del usuario (ABSTAIN por defecto si no ha votado).
     */
    function getUserVote(
        uint256 proposalId,
        address user
    ) external view returns (VoteType) {
        return _userVotes[proposalId][user];
    }
}

// ====================================================================
//  (0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 - Address 0
//  (0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 - Private Key 0
//  (1) 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 - Addres 1
//  (1) 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d - Private Key 1
//  MinimalForwarder deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3
//  DAOVoting deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
//
//Available Accounts
//==================
//
//(0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000.000000000000000000 ETH)
//(1) 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000.000000000000000000 ETH)
//(2) 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (10000.000000000000000000 ETH)
//(3) 0x90F79bf6EB2c4f870365E785982E1f101E93b906 (10000.000000000000000000 ETH)
//(4) 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 (10000.000000000000000000 ETH)
//(5) 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc (10000.000000000000000000 ETH)
//(6) 0x976EA74026E726554dB657fA54763abd0C3a0aa9 (10000.000000000000000000 ETH)
//(7) 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955 (10000.000000000000000000 ETH)
//(8) 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f (10000.000000000000000000 ETH)
//(9) 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 (10000.000000000000000000 ETH)
//
//Private Keys
//==================
//
//(0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
//(1) 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
//(2) 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
//(3) 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
//(4) 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a
//(5) 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
//(6) 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e
//(7) 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
//(8) 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97
//(9) 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6
//
// ====================================================================
