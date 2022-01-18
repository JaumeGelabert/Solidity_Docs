// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SubastaSimple {
    address payable public owner;
    uint256 public horaFinalizacionSubasta;

    // Situacion de la subasta
    address public mayorPujador;
    uint256 public mayorPuja;

    mapping(address => uint256) devolucionesPendientes;

    bool subastaFinalizada;

    // Los siguientes eventos se emitirán cuando haya cambios
    event nuevaMayorPuja(address pujador, uint256 cantidad);
    event subastaTerminada(address ganador, uint256 cantidad);

    // Posibles errores
    /// La subasta ya ha terminado!
    error SubastaYaTerminada();
    /// Oferta igual o inferior a la actual!
    error PujaInsuficiente();
    /// La subasta todavia esta activa!
    error SubastaActiva();
    /// La funcion 'finSubasta' ya se ha llamado previamente!
    error TerminarSubasta();

    constructor(uint256 duracionSubasta, address payable direccionOwner) {
        owner = direccionOwner;
        horaFinalizacionSubasta = block.timestamp + duracionSubasta;
    }

    // Mediante esta función, se permite pujar en la subasta.
    function pujar() external payable {
        // Comprueba que la subasta todavia este activa (no se debe de
        // haber acabado el tiempo). En caso de que haya terminado, la puja
        // no será valida y se devolvera el Ether.
        if (block.timestamp > horaFinalizacionSubasta) {
            revert SubastaYaTerminada();
        }

        // Si la puja es igual o inferior a la anterior, se hace revert.
        // msg.value es el parametro que pasamos en 'value' en el menu
        // para desplegar contratos en RemixIDE
        if (msg.value <= mayorPuja) {
            revert PujaInsuficiente();
        }

        // Si hay alguna puja, se ejecuta el siguiente bloque de código.
        if (mayorPuja != 0) {
            devolucionesPendientes[mayorPujador] += mayorPuja;
        }

        // Si todo es correcto hasta aquí, actualizamos los siguientes datos.
        mayorPujador = msg.sender;
        mayorPuja = msg.value;
        emit nuevaMayorPuja(mayorPujador, mayorPuja);
    }

    // Mediante esta funcion, los usuarios que hayan visto superada su oferta,
    // podran recuperar su fondos.
    function recuperarFondos() external returns (bool) {
        uint256 cantidad = devolucionesPendientes[msg.sender];
        if (cantidad > 0) {
            devolucionesPendientes[msg.sender] = 0;

            if (!payable(msg.sender).send(cantidad)) {
                devolucionesPendientes[msg.sender] = cantidad;
                return false;
            }
        }
        return true;
    }

    function finSubasta() external {
        if (block.timestamp < horaFinalizacionSubasta) {
            revert SubastaActiva();
        }

        if (subastaFinalizada) {
            revert SubastaYaTerminada();
        }

        subastaFinalizada = true;
        emit subastaTerminada(mayorPujador, mayorPuja);

        owner.transfer(mayorPuja);
    }
}
