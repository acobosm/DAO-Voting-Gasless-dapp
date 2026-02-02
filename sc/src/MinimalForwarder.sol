// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Definición de la estructura de la meta-transacción (EIP-712 / EIP-2771)
struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes data;
}

/**
 * @title MinimalForwarder
 * @notice Implementación de un Forwarder Simple compatible con EIP-2771.
 * Se encarga de verificar la firma del usuario y ejecutar la llamada
 * en nombre del remitente original (el campo 'from' de la solicitud).
 * @dev Este contrato debe ser 'trusted' por el contrato DAO Voting (ERC2771Context).
 */
contract MinimalForwarder is Nonces {
    using SafeCast for uint256;

    // Constantes para el dominio EIP-712 (usadas para la firma)
    bytes32 private immutable _TYPE_HASH =
        keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
        );
    bytes32 private immutable _DOMAIN_SEPARATOR;

    // ====================================================================
    // 1. CONSTRUCTOR
    // ====================================================================

    constructor(string memory name) {
        // Inicializa el separador de dominio EIP-712 (Domain Separator)
        _DOMAIN_SEPARATOR = _buildDomainSeparator(name);
    }

    // ====================================================================
    // 2. MÉTODOS REQUERIDOS (EIP-2771)
    // ====================================================================

    /**
     * @notice Retorna el nonce actual de un usuario para prevenir Replay Attacks.
     * @param from Dirección del usuario.
     * @return uint256 Nonce actual.
     */
    function getNonce(address from) public view virtual returns (uint256) {
        // La implementación de OpenZeppelin Nonces.sol ya nos da esta funcionalidad.
        // La función `nonces(address)` es la que usamos para obtener el nonce.
        return nonces(from);
    }

    /**
     * @notice Valida una meta-transacción firmada.
     * @param req Estructura de la solicitud.
     * @param signature Firma del usuario.
     * @return bool Verdadero si la firma es válida y el nonce es correcto.
     */
    function verify(
        ForwardRequest calldata req,
        bytes calldata signature
    ) public view returns (bool) {
        // 1. Verificar Nonce
        if (req.nonce != nonces(req.from)) {
            return false;
        }

        // 2. Reconstruir la firma y verificar
        bytes32 digest = _getHash(req);
        address signer = ECDSA.recover(digest, signature);

        return signer == req.from;
    }

    /**
     * @notice Ejecuta una meta-transacción validada por el relayer.
     * @param req Estructura de la solicitud.
     * @param signature Firma del usuario.
     * @return success Verdadero si la ejecución fue exitosa.
     * @return ret El resultado de la llamada interna.
     * @dev Paga el gas de la transacción y se asegura de incrementar el nonce.
     */
    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) public payable virtual returns (bool success, bytes memory ret) {
        // Valida la firma. Si es válida, incrementa el nonce del usuario 'req.from'.
        // Aquí usamos la implementación de OpenZeppelin Nonces, que aumenta el nonce
        // automáticamente cuando la función `_useNonce` es llamada dentro de `verify`.
        require(verify(req, signature), "MinimalForwarder: signature invalid");

        // **************** IMPORTANTE ****************
        // OpenZeppelin ERC2771Context (que usaremos en el DAO Voting) requiere
        // que el nonce se incremente *antes* de la llamada.
        // Para usar Nonces.sol de OpenZeppelin, debemos incrementar el nonce
        // manualmente después de verificar:

        _useNonce(req.from);

        // 3. Ejecutar la llamada al contrato destino (DAO Voting)
        (success, ret) = req.to.call{value: req.value, gas: req.gas.toUint64()}(
            _encodeFunctionCall(req.data, req.from)
        );

        // Si la llamada falla, revertimos
        if (!success) {
            // Revertir con el mensaje de error de la llamada interna
            if (ret.length > 0) {
                assembly {
                    revert(add(32, ret), mload(ret))
                }
            } else {
                revert("MinimalForwarder: call failed");
            }
        }
    }

    // ====================================================================
    // 3. FUNCIONES INTERNAS
    // ====================================================================

    /**
     * @notice Función interna para construir el separador de dominio EIP-712.
     */
    function _buildDomainSeparator(
        string memory name
    ) private view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        return
            keccak256(
                abi.encode(
                    typeHash,
                    keccak256(bytes(name)), // Hash del nombre
                    keccak256(bytes("1")), // Requiere que la cadena sea convertida a bytes antes de aplicar keccak256
                    chainId,
                    address(this)
                )
            );
    }

    /**
     * @notice Calcula el hash EIP-712 de la solicitud.
     */
    function _getHash(
        ForwardRequest calldata req
    ) private view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                _TYPE_HASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                req.nonce,
                keccak256(req.data)
            )
        );

        // Hash final = keccak256(DOMAIN_SEPARATOR + STRUCT_HASH)
        return
            keccak256(
                abi.encodePacked(
                    bytes1(0x19),
                    bytes1(0x01),
                    _DOMAIN_SEPARATOR,
                    structHash
                )
            );
    }

    /**
     * @notice Codifica la llamada a la función agregando la dirección del remitente al final (EIP-2771).
     * @param data Datos de la función.
     * @param forwarder Remitente original (el usuario).
     */
    function _encodeFunctionCall(
        bytes memory data,
        address forwarder
    ) private pure returns (bytes memory) {
        // EIP-2771 requiere que la dirección del remitente (el 'from' de la meta-transacción)
        // se añada al final de los datos de la llamada (data).
        return abi.encodePacked(data, forwarder);
    }
}
