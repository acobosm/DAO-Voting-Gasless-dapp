// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MinimalForwarder} from "../src/MinimalForwarder.sol";
import {DAOVoting} from "../src/DAOVoting.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployDAOScript
 * @notice Script para desplegar el MinimalForwarder y el DAOVoting.
 * Este script se usa para obtener las direcciones de los contratos en una red específica.
 */
contract DeployDAOScript is Script {
    function run()
        public
        returns (address forwarderAddress, address daoAddress)
    {
        // La clave privada de la cuenta de despliegue se obtiene de las variables de entorno
        // o se configura al ejecutar `forge script`. Usamos `vm.startBroadcast()` para esto.

        vm.startBroadcast();

        // 1. Desplegar el MinimalForwarder
        // El constructor requiere un string 'name' para el dominio EIP-712.
        MinimalForwarder forwarder = new MinimalForwarder("DAOVotingForwarder");
        forwarderAddress = address(forwarder);

        console.log("MinimalForwarder deployed at:", forwarderAddress);

        // 2. Desplegar el DAO Voting
        // El constructor de DAOVoting requiere la dirección del forwarder (trustedForwarder).
        DAOVoting dao = new DAOVoting(forwarderAddress);
        daoAddress = address(dao);

        console.log("DAOVoting deployed at:", daoAddress);

        vm.stopBroadcast();

        // Retornamos las direcciones para usarlas en el frontend/relayer
        // Nota: Solo se retornan si se ejecuta con el flag `--json`
    }
}
