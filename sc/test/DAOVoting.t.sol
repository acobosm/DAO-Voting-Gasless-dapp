// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol"; // ******* AÑADIDO PARA VER LAS ADDRESS FORWARDER Y DAO *******
import {MinimalForwarder, ForwardRequest} from "../src/MinimalForwarder.sol";
import {DAOVoting} from "../src/DAOVoting.sol";
// Nota: La importación de VoteType y ProposalState se hace usando el prefijo DAOVoting.

/**
 * @title DAOVotingTest
 * @notice Tests de integración para DAOVoting y MinimalForwarder.
 * Simula el flujo de las meta-transacciones (Gasless).
 */
contract DAOVotingTest is Test {
    MinimalForwarder public forwarder;
    DAOVoting public dao;

    /*// Usuarios de prueba (cuentas de Anvil)  // ******* BLOQUE A SER ELIMINADO SI LA SIGNATURE DE LOS TEST AL FIN COINCIDE *******
    address public constant ALICE = address(1);
    address public constant BOB = address(2);*/

    address public constant CAROL = address(3);
    address public constant RELAYER = address(0xAA); // La cuenta que paga el gas
    address public ALICE; // Dejamos de usar address(1)
    address public BOB; // Dejamos de usar address(2)
    uint256 public constant ALICE_PK = 0x1; // Clave privada ficticia
    uint256 public constant BOB_PK = 0x2; // Clave privada ficticia

    // **************************************
    /**
     * @dev Permite al contrato de test recibir ETH.
     * Sin esto, la función withdraw() de la DAO fallará al intentar devolvernos dinero.
     */
    receive() external payable {}
    // **************************************

    function setUp() public {
        // 0. FORZAR LA CHAIN ID ******* (¡CAMBIO INTRODUCIDO PORQUE EL SIGNATURE DE LOS TEST NO COINCIDEN Y EL TEST FALLA!) *******
        vm.chainId(31337); // Establece la Chain ID por defecto de Anvil

        // 0. B) OBTENER LAS DIRECCIONES REALES DE LAS LLAVES PRIVADAS (¡CRÍTICO!)
        ALICE = vm.addr(ALICE_PK); // ALICE ahora es la dirección real de la llave 0x1
        BOB = vm.addr(BOB_PK); // BOB ahora es la dirección real de la llave 0x2 (0x2B5AD5...)

        // 1. Desplegar el MinimalForwarder
        forwarder = new MinimalForwarder("DAOVotingForwarder");
        console.log("FORWARDER_ADDRESS: ", address(forwarder)); // <-- Temporal para visualizar la dirección Forwarder

        // 2. Desplegar el DAO Voting
        dao = new DAOVoting(address(forwarder));
        console.log("DAO_VOTING_ADDRESS: ", address(dao)); // <-- Temporal para visualizar la dirección DAO

        // 3. Fondeo inicial de las cuentas de prueba
        vm.deal(ALICE, 10 ether);
        vm.deal(BOB, 10 ether);
        vm.deal(CAROL, 10 ether);
        vm.deal(RELAYER, 10 ether);

        // 4. Fondeo del DAO
        vm.startPrank(ALICE);
        dao.fundDao{value: 5 ether}(); // ALICE fondea 5 ETH
        vm.stopPrank();

        vm.startPrank(BOB);
        dao.fundDao{value: 5 ether}(); // BOB fondea 5 ETH
        vm.stopPrank();

        // Total DAO Balance = 10 ETH
    }

    // ====================================================================
    // 1. TESTS DE GOBERNANZA (NO-GASLESS)
    // ====================================================================

    function test_Propose_Success() public {
        // ALICE tiene 5 ETH, el total es 10 ETH. Cumple el requisito de 10%.
        vm.startPrank(ALICE);
        uint256 deadline = block.timestamp + 1 days;
        dao.createProposal("Mejorar servidores", CAROL, 1 ether, deadline);
        vm.stopPrank();

        // Corregido: Asignar la estructura completa para evitar error 7364
        DAOVoting.Proposal memory proposal = dao.getProposal(1);

        assertEq(proposal.id, 1, "Proposal ID incorrecto");
        assertEq(
            proposal.description,
            "Mejorar servidores",
            "Descripcion incorrecta"
        );
        assertEq(proposal.recipient, CAROL, "Recipient incorrecto");
        assertEq(proposal.amount, 1 ether, "Amount incorrecto");
    }

    function test_Propose_Fail_InsufficientBalance() public {
        // CAROL no tiene fondos, debe fallar.
        vm.startPrank(CAROL);
        uint256 deadline = block.timestamp + 1 days;

        vm.expectRevert(
            "DAOVoting: Insufficient balance. Must hold >= 10% of total DAO balance to propose."
        );
        dao.createProposal("Test Proposal", CAROL, 1 ether, deadline);
        vm.stopPrank();
    }

    // ====================================================================
    // 2. FUNCIÓN DE UTILIDAD: FIRMA EIP-712 (CORREGIDA)
    // ====================================================================

    /**
     * @notice Simula la firma de una Meta-Transacción EIP-712 off-chain.
     */
    function _signMetaTx(
        address signer,
        uint256 privateKey,
        address target,
        bytes memory callData
    )
        internal
        view
        returns (ForwardRequest memory req, bytes memory signature)
    {
        // 1. Obtener el Nonce actual del usuario
        uint256 nonce = forwarder.getNonce(signer);

        // 2. Construir la solicitud (ForwardRequest)
        req = ForwardRequest({
            from: signer,
            to: target,
            value: 0,
            gas: 1_000_000,
            nonce: nonce,
            data: callData
        });

        // 3. Replicar el cálculo del HASH EIP-712 (como se hace en MinimalForwarder)
        bytes32 typeHash = keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
        );
        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                req.from,
                req.to,
                req.value,
                req.gas,
                req.nonce,
                keccak256(req.data)
            )
        );

        uint256 chainId; // ******* BLOQUE A SER ELIMINADO EN  CASO QUE vm.chainid() FUNCIONE *******
        assembly {
            chainId := chainid()
        }

        //uint256 chainId = vm.chainid();  // ******* SE ESTA PROBANDO ENTRE ASSEMBLY DEL BLOQUE ANTERIOR Y ESTA LINEA A VER CUAL QUEDA *******

        bytes32 domainTypeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                domainTypeHash,
                keccak256(bytes("DAOVotingForwarder")),
                keccak256(bytes("1")),
                chainId,
                address(forwarder)
            )
        );

        // 4. Calcular el Typed Data Hash final (Corregido el tipo de datos para keccak256)
        // keccak256 en Solidity solo toma bytes memory. abi.encodePacked devuelve bytes memory.
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                structHash
            )
        );

        // 5. Firmar el hash (Corregido el uso de vm.sign)
        // vm.sign toma bytes32 como hash, lo cual ya es 'hash'
        //signature = vm.sign(privateKey, hash); // vm.sign retorna bytes  // ******* LINEA A ELIMINAR *******
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        signature = abi.encodePacked(r, s, v);
    }

    // ====================================================================
    // 3. TESTS DE INTEGRACIÓN GASLESS (Votación)
    // ====================================================================

    function test_VoteGasless_Success() public {
        // 1. Preparación: ALICE crea una propuesta para que BOB pueda votar.
        vm.startPrank(ALICE);
        uint256 deadline = block.timestamp + 1 days;
        dao.createProposal("Test Proposal", CAROL, 1 ether, deadline);
        vm.stopPrank();

        // 2. Usuario OFF-CHAIN (BOB) prepara la llamada a votar
        uint256 proposalId = 1;
        bytes memory callData = abi.encodeWithSelector(
            dao.vote.selector,
            proposalId,
            DAOVoting.VoteType.FOR // Corregido: Prefijo DAOVoting.
        );

        // 3. Usuario OFF-CHAIN (BOB) firma la meta-transacción
        (ForwardRequest memory req, bytes memory signature) = _signMetaTx(
            BOB,
            BOB_PK,
            address(dao),
            callData
        );

        // 4. RELAYER (Gas Payer) ejecuta la meta-transacción ON-CHAIN
        vm.prank(RELAYER);
        (bool success, ) = forwarder.execute(req, signature);

        // 5. Verificaciones (Corregido el casting para assertEq, VoteType es uint8)
        assertTrue(success, "Execution failed in Forwarder.");
        // Casting a uint256 para evitar Error 9322 (assertEq)
        assertEq(
            uint256(dao.getUserVote(proposalId, BOB)),
            uint256(DAOVoting.VoteType.FOR),
            "BOB's vote was not registered."
        );

        // Verificación de Nonce
        assertEq(forwarder.getNonce(BOB), 1, "Nonce was not incremented.");
    }

    function test_VoteGasless_Fail_InvalidNonce() public {
        // 1. Preparación
        vm.startPrank(ALICE);
        uint256 deadline = block.timestamp + 1 days;
        dao.createProposal("Test Proposal", CAROL, 1 ether, deadline);
        vm.stopPrank();

        uint256 proposalId = 1;
        bytes memory callData = abi.encodeWithSelector(
            dao.vote.selector,
            proposalId,
            DAOVoting.VoteType.FOR
        ); // Corregido el prefijo

        // 2. BOB firma la meta-transacción (Nonce=0)
        (ForwardRequest memory req, bytes memory signature) = _signMetaTx(
            BOB,
            BOB_PK,
            address(dao),
            callData
        );

        // 3. Primera ejecución exitosa (Nonce=0 usado)
        vm.prank(RELAYER);
        forwarder.execute(req, signature);

        // 4. Intento de re-ejecución (Replay Attack) con la misma firma (Nonce=0)
        vm.prank(RELAYER);
        vm.expectRevert("MinimalForwarder: signature invalid");
        forwarder.execute(req, signature);
    }

    // ====================================================================
    // 4. TESTS DE EJECUCIÓN
    // ====================================================================

    function test_ExecuteProposal_Success_Approved() public {
        // 1. Preparación: ALICE crea una propuesta de 2 ETH para CAROL
        vm.startPrank(ALICE);
        uint256 proposalAmount = 2 ether;
        uint256 deadline = block.timestamp + 1 days;
        dao.createProposal("Test Proposal", CAROL, proposalAmount, deadline);
        vm.stopPrank();

        uint256 proposalId = 1;

        // 2. Votación Gasless (A FAVOR)
        bytes memory callData = abi.encodeWithSelector(
            dao.vote.selector,
            proposalId,
            DAOVoting.VoteType.FOR
        ); // Corregido el prefijo
        (ForwardRequest memory req, bytes memory signature) = _signMetaTx(
            BOB,
            BOB_PK,
            address(dao),
            callData
        );

        vm.prank(RELAYER);
        forwarder.execute(req, signature);

        // 3. Simular que el tiempo ha pasado
        vm.warp(block.timestamp + 2 days);

        // 4. Verificación de Balances ANTES
        uint256 daoBalanceBefore = address(dao).balance;
        uint256 carolBalanceBefore = CAROL.balance;

        // 5. Ejecutar la propuesta
        vm.prank(ALICE);
        dao.executeProposal(proposalId);

        // 6. Verificaciones
        assertEq(
            address(dao).balance,
            daoBalanceBefore - proposalAmount,
            "DAO balance incorrecto."
        );
        assertEq(
            CAROL.balance,
            carolBalanceBefore + proposalAmount,
            "Recipient balance incorrecto."
        );

        // Corregido: Asignar la estructura completa
        DAOVoting.Proposal memory proposal = dao.getProposal(proposalId);
        // Corregido: Prefijo DAOVoting. y casting a uint256
        assertEq(
            uint256(proposal.state),
            uint256(DAOVoting.ProposalState.Executed),
            "State no es Executed."
        );
        assertTrue(proposal.executed, "Flag executed no es true.");
    }

    function test_ExecuteProposal_Fail_RejectedAndTiming() public {
        // 1. Preparación: ALICE crea una propuesta de 1 ETH para CAROL
        vm.startPrank(ALICE);
        uint256 deadline = block.timestamp + 1 days;
        dao.createProposal("Test Proposal", CAROL, 1 ether, deadline);
        vm.stopPrank();

        uint256 proposalId = 1;

        // 2. Test: Fallo por tiempo (Deadline no ha pasado)
        vm.startPrank(ALICE);
        vm.expectRevert("DAOVoting: Voting is still active.");
        dao.executeProposal(proposalId);
        vm.stopPrank();

        // 3. Votación Gasless (EN CONTRA)
        bytes memory callData = abi.encodeWithSelector(
            dao.vote.selector,
            proposalId,
            DAOVoting.VoteType.AGAINST
        ); // Corregido el prefijo
        (ForwardRequest memory req, bytes memory signature) = _signMetaTx(
            BOB,
            BOB_PK,
            address(dao),
            callData
        );

        vm.prank(RELAYER);
        forwarder.execute(req, signature);

        // 4. Simular que el tiempo ha pasado
        vm.warp(block.timestamp + 2 days);

        // 5. Ejecución (Debe fallar internamente y pasar a estado REJECTED)
        vm.prank(ALICE);
        dao.executeProposal(proposalId);

        // Verificación de estado: Debe ser REJECTED
        // Corregido: Asignar la estructura completa
        DAOVoting.Proposal memory proposal = dao.getProposal(proposalId);
        // Corregido: Prefijo DAOVoting. y casting a uint256
        assertEq(
            uint256(proposal.state),
            uint256(DAOVoting.ProposalState.Rejected),
            "State no es Rejected."
        );

        // Verificación de doble ejecución
        vm.expectRevert("DAOVoting: Proposal already executed.");
        dao.executeProposal(proposalId);
    }

    function test_Vote_Fail_InvalidTypeNone() public {
        // 1. Preparación
        vm.startPrank(ALICE);
        uint256 deadline = block.timestamp + 1 days;
        dao.createProposal("Test Proposal", CAROL, 1 ether, deadline);
        vm.stopPrank();

        // 2. Intentar votar con NONE (Esto debe disparar el nuevo require)
        vm.startPrank(BOB);
        vm.expectRevert("DAOVoting: Invalid vote type.");
        dao.vote(1, DAOVoting.VoteType.NONE); // Intentando usar el valor 0
        vm.stopPrank();
    }

    function testWithdraw() public {
        // 1. Configuración: Usamos 2 ETH para esta prueba
        uint256 depositAmount = 2 ether;
        uint256 initialDaoBalance = dao.getTotalDaoBalance(); // Debería ser 10 ETH por el setUp

        // Depositamos como 'address(this)' (el contrato de test)
        dao.fundDao{value: depositAmount}();

        // 2. Ejecución: Retiramos
        dao.withdraw();

        // 3. Verificación
        // El balance debe regresar a lo que había inicialmente (10 ETH)
        assertEq(
            dao.getTotalDaoBalance(),
            initialDaoBalance,
            "El balance global no regreso al estado inicial"
        );
        // El balance específico de este contrato de test en la DAO debe ser 0
        assertEq(
            dao.getUserBalance(address(this)),
            0,
            "El balance del usuario deberia ser 0"
        );
    }
}
