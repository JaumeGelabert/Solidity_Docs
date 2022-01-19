// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

contract subastaCiega {
    // Declaramos el tipo de dato 'Oferta'. Como variables
    // encontramos de tipo bytes32 y otra uint.
    struct Puja {
        bytes32 pujaCiega;
        uint256 deposito;
    }

    address payable public owner;
    uint256 public finPujas;
    uint256 public mostrarResultados;
    bool public haTerminado;

    // Mapping que relaciona una dirección con un array de
    // tipo Puja, que esta formado por un bytes32 y un uint.
    mapping(address => Puja[]) public pujas;

    address public mayorPujador;
    uint256 public mayorPuja;

    // El siguiente mapping permite el correcto funcionamiento
    // de 'hacerPuja'.
    mapping(address => uint256) devolucionesPendientes;

    event subastaFinalizada(address ganador, uint256 mayorPuja);

    // Errores

    /// La funcion se ha llamado demasiado pronto
    /// Prueba otra vez a 'time'
    error demasiadoPronto(uint256 time);
    /// La funcion se ha llamado demasiado tarde
    /// No puede ser llamada despues de 'time'
    error demasiadoTarde(uint256 time);
    /// La funcion finSubasta ya se ha llamado
    error finSubastaYaLlamada();

    // Mediante este modificador, comprobamos que la funcion
    // en la que encontremos este modificador, solo se podra
    // llamar antes de de 'tiempo'.
    // En caso de que en el momento de llamar la función nos
    // encontremos en un momento posterior a 'tiempo', se
    // ejecutara el 'revert'.
    // Mas adelante, se sustiuye 'tiempo' por 'finPujas'
    // teniendo asi mas sentido el modifier.
    modifier soloAntes(uint256 tiempo) {
        // Si ahora es mas tarde que 'tiempo', se ejecutara el
        // revert.
        if (block.timestamp >= tiempo) revert demasiadoTarde(tiempo);
        _;
    }

    // Este modifier es el inverso del anterior. Solo se podrá
    // llamar la funcion afectada cuando nos encontremos en un
    // momento del tiempo posterior a 'tiempo'.
    modifier soloDespues(uint256 tiempo) {
        // Si ahora es mas pronto que 'tiempo', se ejecutara el
        // revert.
        if (block.timestamp <= tiempo) revert demasiadoPronto(tiempo);
        _;
    }

    constructor(
        // Determinara el tiempo en segundos que tendran los
        // participantes para hacer sus pujas.
        uint256 tiempoPujas,
        uint256 mostrarResultadosTiempo,
        address payable addressOwner
    ) {
        // No se asigna la direccion de despliegue del contrato
        // a la variable owner ya que puede que despleguemos
        // nosotros el contrato y asignemos otra direccion como
        // beneficiario.
        owner = addressOwner;
        // Determina el momento en el que se terminara el tiempo
        // para hacer pujas. Suma del tiempo en el que se despliega
        // el contrato y el 'tiempoPujas' que se determine.
        finPujas = block.timestamp + tiempoPujas;
        // Una vez terminado el tiempo para hacer pujas, se podran
        // mostrar los resultados. Suma del tiempo en el que terminan
        // las pujas y 'mostrarResultadosTiempo'.
        mostrarResultados = finPujas + mostrarResultadosTiempo;
    }

    // Como parametro debemos pasar un hash que siga la siguiente estructura:
    // _pujaCiega = keccak256(abi.endodePacked(value, fake, secret)
    // Mas detalle en la pagina 31 de la documentacion de solidity.
    function pujar(bytes32 _pujaCiega) external payable soloAntes(finPujas) {
        pujas[msg.sender].push(
            Puja({pujaCiega: _pujaCiega, deposito: msg.value})
        );
    }

    function desvelar(
        uint256[] calldata values,
        bool[] calldata fakes,
        bytes32[] calldata secrets
    ) external soloDespues(finPujas) soloAntes(mostrarResultados) {
        uint256 length = pujas[msg.sender].length;
        // Mediante los siguientes requires comprobamos que haya el
        // mismo numero de elementos en las variables que el numero
        // de pujas. En otras palabras, que todas las pujas hayan
        // sido introducidas de manera completa.
        require(values.length == length);
        require(fakes.length == length);
        require(secrets.length == length);

        uint256 devolucion;
        for (uint256 i = 0; i < length; i++) {
            // En la variable de tipo Puja guardamos la puja 'i'
            // asociada a la direccion mendiante el mapping 'pujas'.
            Puja storage comprobarPuja = pujas[msg.sender][i];
            (uint256 value, bool fake, bytes32 secret) = (
                values[i],
                fakes[i],
                secrets[i]
            );

            if (
                comprobarPuja.pujaCiega !=
                keccak256(abi.encodePacked(value, fake, secret))
            ) {
                continue;
            }
            devolucion += comprobarPuja.deposito;

            if (!fake && comprobarPuja.deposito >= value) {
                if (hacerPuja(msg.sender, value)) {
                    devolucion -= value;
                }
            }
            // Hacemos imposible que el pujador vuelva a solicitar
            // la devolucion de una puja ya reclamada.
            comprobarPuja.pujaCiega = bytes32(0);
        }
        payable(msg.sender).transfer(devolucion);
    }

    // Devolvemos una puja superada
    function devolverPujaSuperada() external soloDespues(mostrarResultados) {
        if (haTerminado) {
            revert finSubastaYaLlamada();
        }

        emit subastaFinalizada(mayorPujador, mayorPuja);
        haTerminado = true;
        owner.transfer(mayorPuja);
    }

    function hacerPuja(address _pujador, uint256 _valor)
        internal
        returns (bool success)
    {
        if (_valor <= mayorPuja) {
            return false;
        }
        if (mayorPujador != address(0)) {
            devolucionesPendientes[mayorPujador] += mayorPuja;
        }

        mayorPuja = _valor;
        mayorPujador = _pujador;
        return true;
    }
}
