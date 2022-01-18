// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Mediante este contrato, se podrá ejercer una votación. Se podrá delegar el voto
// El papel del 'moderador' será importante, ya que solo él
// podrá acceder a ciertas funciones
contract Votacion {
    // Estructura para vontante
    struct Votante {
        uint256 fuerza; // Se acumula 'fuerza' cuando se obtiene un voto delegado
        bool haVotado; // Si es true, la persona ya ha votado
        address delegado; // Persona a la que ha delegado su voto
        uint256 vote; // Índice del candidato que ha votado
    }

    // Estructura para candidato
    struct Candidato {
        bytes32 nombre; // Debe caber dentro de 32 bytes
        uint256 votos; // Total de votos que ha obtenido el candidato
    }

    address public moderador;

    // Vinculamos la estructura compleja 'Votante' previamente declarada con la dirección
    // de cada persona que interactue con el contrato
    mapping(address => Votante) public votantes;

    // Array dinámico de tipo complejo 'Candidato'. En este array se almacenarán todas
    // las propuestas
    Candidato[] public candidaturas;

    // 'constructor' solo se ejecuta cuando se despliega el contrato, por lo que las
    // variables que se inicializan en el, no deberían cambiar de valor
    constructor(bytes32[] memory nombresCandidatos) {
        moderador = msg.sender;
        // Mediante el mapping 'votantes', pasando el keyValue de la dirección del
        // moderador, le asignamos al mismo una fuerza de 1
        votantes[moderador].fuerza = 1;

        // Añadimos cada nombre pasado por el moderador como candidatos al array
        // de tipo candidato creado con el nombre de 'candidaturas'.
        for (uint256 i = 0; i < nombresCandidatos.length; i++) {
            candidaturas.push(
                Candidato({nombre: nombresCandidatos[i], votos: 0})
            );
        }
    }

    // Funcion para asignar el derecho a voto. Solo la podra utilizar el moderador
    function asignarDerechoVoto(address votante) external view {
        // Comprobamos que el que ejecuta la funcion es el moderador
        require(
            msg.sender == moderador,
            "Solo el moderador puede ejecutar esta funcion!"
        );
        // Compromabos que el votante no haya votado previamente
        require(
            //La siguiente linea podria escribirse tambien de la siguiente forma:
            /*
                votantes[votante].haVotado == false;
            */
            // Si se cumple que la condición sea false, quiere decir que no ha votado.
            // Si añadimos el modificador '!', decimos que en el caso de que devuelva
            // 'true', se para la ejecución y mostramos el mensaje de que ya ha votado.
            !votantes[votante].haVotado,
            "Esta persona ya ha votado!"
        );
        // Si la 'fuerza' del votante es diferente a 0, ya puede votar.
        require(
            votantes[votante].fuerza == 0,
            "El votante no tiene 'fuerza' para votar. No le quedan votos!"
        );
        // Si no ha saltado ningun require, asignamos fuerza 1
        votantes[votante].fuerza == 1;
    }

    // Funcion para delegar el voto a un 'representante'
    function delegarVoto(address representante) external {
        Votante storage delegante = votantes[msg.sender];
        // Si no se cumple que el delegante no haya votado (es decir, si ya ha votado)
        // se para la ejecucion.
        require(
            !delegante.haVotado,
            "Ya ha votado. No se puede delegar el voto!"
        );
        require(
            msg.sender != representante,
            "No puedes autodelegarte el voto!"
        );

        // Mientras la direccion el delegado del votante sea diferente a 0 (es decir,
        // tenga una dirección en la que delega los votos), se ejecutará el siguiente loop
        while (votantes[representante].delegado != address(0)) {
            representante = votantes[representante].delegado;
            require(representante != msg.sender);
        }

        // Asignamos al delegante (delegante = votantes[msg.sender]) que ha delegado su
        // voto y añadimos la dirección de la persona a la que ha delegado su voto
        delegante.haVotado = true;
        delegante.delegado = representante;

        Votante storage delegados = votantes[representante];
        if (delegados.haVotado) {
            // Si a la persona a la que hemos delegado el voto ya ha votado, añadimos el voto
            // que acaba de recibir a la persona que ya ha votado.
            candidaturas[delegados.vote].votos += delegante.fuerza;
        } else {
            // si el delegado todavía no ha votado, se le añade 'fuerza'
            delegados.fuerza += delegante.fuerza;
        }
    }

    // Mediante la siguiente función se podrá votar. El voto propio y todos aquellos que se
    // hayan obtenido mediante delegación de votos
    function votar(uint256 _candidato) external {
        Votante storage sender = votantes[msg.sender];
        // La fuerza debe ser mayor que 0 para poder votar
        // Para poder seguir, es necesario que 'fuerza' del sender sea diferente a 0
        require(sender.fuerza != 0, "No tienes derecho a voto!");
        // 'haVotado' debe ser false para seguir con la ejecución del código
        require(!sender.haVotado, "Ya has votado");
        sender.haVotado = true;
        sender.vote = _candidato;
        candidaturas[_candidato].votos += sender.fuerza;
    }

    function votosGanador() public view returns (uint256 ganador_) {
        uint256 _votosGanador = 0;
        for (uint256 i = 0; i < candidaturas.length; i++) {
            _votosGanador = candidaturas[i].votos;
            ganador_ = i;
        }
    }

    function nombreGanador() external view returns (bytes32 nombreGanador_) {
        nombreGanador_ = candidaturas[votosGanador()].nombre;
    }
}
