// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


contract CCNFT is ERC721Enumerable, Ownable, ReentrancyGuard {

//EVENTOS
// indexed: Permiten realizar búsquedas en los registros de eventos.


// Compra NFTs
    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value); 
// buyer: La dirección del comprador.

// tokenId: El ID único del NFT comprado.

// value: El valor asociado al NFT comprado.


// Reclamamo NFTs.
    event Claim(address indexed claimer, uint256 indexed tokenId);
// claimer: La dirección del usuario que reclama los NFTs.
// tokenId: El ID único del NFT reclamado.

// Transferencia de NFT de un usuario a otro.
    event Trade(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 value
    );
// buyer: La dirección del comprador del NFT.
// seller: La dirección del vendedor del NFT.
// tokenId: El ID único del NFT que se transfiere.
// value: El valor pagado por el comprador al vendedor por el NFT (No indexed).

// Venta de un NFT.
    event PutOnSale(
        uint256 indexed tokenId,
        uint256 price
    );
// tokenId: El ID único del NFT que se pone en venta.
// price: El precio al cual se pone en venta el NFT (No indexed).

// Estructura del estado de venta de un NFT.
    struct TokenSale {
        bool onSale;      // Indicamos si el NFT está en venta.
        uint256 price;    // Indicamos el precio del NFT si está en venta.
    }

// Biblioteca Counters de OpenZeppelin para manejar contadores de manera segura.
    using Counters for Counters.Counter; 

// Contador para asignar IDs únicos a cada NFT que se crea.
    Counters.Counter private tokenIdTracker;

// Mapeo del ID de un token (NFT) a un valor específico.
    mapping(uint256 => uint256) public values;

// Mapeo de un valor a un booleano para indicar si el valor es válido o no.
    mapping(uint256 => bool) public validValues;

// Mapeo del ID de un token (NFT) a su estado de venta (TokenSale).
    mapping(uint256 => TokenSale) public tokensOnSale;

// Lista que contiene los IDs de los NFTs que están actualmente en venta.
    uint256[] public listTokensOnSale;
    
    address public fundsCollector; // Dirección de los fondos de las ventas de los NFTs
    address public feesCollector; // Dirección de las tarifas de transacción (compra y venta de los NFTs)

    bool public canBuy; // Booleano que indica si las compras de NFTs están permitidas.
    bool public canClaim; // Booleano que indica si la reclamación (quitar) de NFTs está permitida.
    bool public canTrade; // Booleano que indica si la transferencia de NFTs está permitida.

    uint256 public totalValue; // Valor total acumulado de todos los NFTs en circulación.
    uint256 public maxValueToRaise; // Valor máximo permitido para recaudar a través de compras de NFTs.

    uint16 public buyFee; // Tarifa aplicada a las compras de NFTs.
    uint16 public tradeFee; // Tarifa aplicada a las transferencias de NFTs.
    
    uint16 public maxBatchCount; // Límite en la cantidad de NFTs por operación (evitar exceder el límite de gas en una transacción).

    uint32 public profitToPay; // Porcentaje adicional a pagar en las reclamaciones.


// Referencia al contrato ERC20 manejador de fondos. 
    IERC20 public fundsToken;

// Constructor (nombre y símbolo del NFT).    
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}


    // PUBLIC FUNCTIONS

// Funcion de compra de NFTs. 

// Parametro value: El valor de cada NFT que se está comprando.
// Parametro amount: La cantidad de NFTs que se quieren comprar.
     function buy(uint256 value, uint256 amount) external nonReentrant {
        require(canBuy, "Buy not allowed");
        require(amount > 0 && amount <= maxBatchCount, "Invalid amount");
        require(validValues[value], "Value not allowed");
        require(totalValue + (value * amount) <= maxValueToRaise, "Exceeds max value to raise");

        totalValue += value * amount;

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = tokenIdTracker.current();
            values[tokenId] = value;
            _safeMint(_msgSender(), tokenId);
            emit Buy(_msgSender(), tokenId, value);
            tokenIdTracker.increment();
        }

        // Transferencia de fondos al collector
        if (!fundsToken.transferFrom(_msgSender(), fundsCollector, value * amount)) {
            revert("Cannot send funds tokens");
        }

        // Transferencia de la fee al collector de fees
        uint256 fee = value * amount * buyFee / 10000;
        if (fee > 0 && !fundsToken.transferFrom(_msgSender(), feesCollector, fee)) {
            revert("Cannot send fees tokens");
        }
    }

// Funcion de "reclamo" de NFTs
// Parámetros: Lista de IDs de tokens de reclamo (utilizar calldata).
    function claim(uint256[] calldata listTokenId) external nonReentrant {
        require(canClaim, "Claim not allowed");
        require(listTokenId.length > 0 && listTokenId.length <= maxBatchCount, "Invalid claim amount");

        uint256 claimValue = 0;
        for (uint256 i = 0; i < listTokenId.length; i++) {
            uint256 tokenId = listTokenId[i];
            require(_exists(tokenId), "Token does not exist");
            require(ownerOf(tokenId) == _msgSender(), "Only owner can Claim");

            claimValue += values[tokenId];
            values[tokenId] = 0;

            TokenSale storage tokenSale = tokensOnSale[tokenId];
            tokenSale.onSale = false;
            tokenSale.price = 0;

            removeFromArray(listTokensOnSale, tokenId);
            _burn(tokenId);
            emit Claim(_msgSender(), tokenId);
        }

        totalValue -= claimValue;

        uint256 totalToTransfer = claimValue + (claimValue * profitToPay / 10000);
        if (!fundsToken.transferFrom(fundsCollector, _msgSender(), totalToTransfer)) {
            revert("cannot send funds");
        }
    }

// Funcion de compra de NFT que esta en venta.
    function trade(uint256 tokenId) external nonReentrant {
        require(canTrade, "Trade not allowed");
        require(_exists(tokenId), "Token does not exist");

        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Buyer is the Seller");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        require(tokenSale.onSale, "Token not On Sale");

        uint256 price = tokenSale.price;
        uint256 fee = price * tradeFee / 10000;

        // Transferencia del precio de venta al vendedor
        if (!fundsToken.transferFrom(msg.sender, seller, price)) {
            revert("Cannot send funds to seller");
        }

        // Transferencia de la tarifa de trade al feesCollector
        if (fee > 0 && !fundsToken.transferFrom(msg.sender, feesCollector, fee)) {
            revert("Cannot send trade fee");
        }

        emit Trade(msg.sender, seller, tokenId, price);

        // Transferencia del NFT al comprador
        _safeTransfer(seller, msg.sender, tokenId, "");

        // Actualizar estado de venta
        tokenSale.onSale = false;
        tokenSale.price = 0;
        removeFromArray(listTokensOnSale, tokenId);
    }

// Función para poner en venta un NFT.
    function putOnSale(uint256 tokenId, uint256 price) external {
        require(canTrade, "Trade not allowed");
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Only owner can put on sale");
        require(price > 0, "Price must be greater than zero");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        tokenSale.onSale = true;
        tokenSale.price = price;

        addToArray(listTokensOnSale, tokenId);

        emit PutOnSale(tokenId, price);
    }

    // SETTERS

// Utilización del token ERC20 para transacciones.
    function setFundsToken(address token) external onlyOwner {
        require(token != address(0), "Token address cannot be zero");
        fundsToken = IERC20(token);
    }

// Dirección para colectar los fondos de las ventas de NFTs.
    function setFundsCollector(address _address) external onlyOwner {
        require(_address != address(0), "Funds collector cannot be zero");
        fundsCollector = _address;
    }

// Dirección para colectar las tarifas de transacción.
    function setFeesCollector(address _address) external onlyOwner {
        require(_address != address(0), "Fees collector cannot be zero");
        feesCollector = _address;
    }

// Porcentaje de beneficio a pagar en las reclamaciones.
    function setProfitToPay(uint32 _profitToPay) external onlyOwner {
        profitToPay = _profitToPay;
    }

// Función que Habilita o deshabilita la compra de NFTs.
    function setCanBuy(bool _canBuy) external onlyOwner {
        canBuy = _canBuy;
    }

// Función que Habilita o deshabilita la reclamación de NFTs.
    function setCanClaim(bool _canClaim) external onlyOwner {
        canClaim = _canClaim;
    }

// Función que Habilita o deshabilita el intercambio de NFTs.
    function setCanTrade(bool _canTrade) external onlyOwner {
        canTrade = _canTrade;
    }

// Valor máximo que se puede recaudar de venta de NFTs.
    function setMaxValueToRaise(uint256 _maxValueToRaise) external onlyOwner {
        maxValueToRaise = _maxValueToRaise;
    }
    
// Función para agregar un valor válido para NFTs.   
    function addValidValues(uint256 value) external onlyOwner {
        validValues[value] = true;
    }

// Función para establecer la cantidad máxima de NFTs por operación.
    function setMaxBatchCount(uint16 _maxBatchCount) external onlyOwner {
        maxBatchCount = _maxBatchCount;
    }

// Tarifa aplicada a las compras de NFTs.
    function setBuyFee(uint16 _buyFee) external onlyOwner {
        buyFee = _buyFee;
    }

// Tarifa aplicada a las transacciones de NFTs.
    function setTradeFee(uint16 _tradeFee) external onlyOwner {
        tradeFee = _tradeFee;
    }


    // ARRAYS

// Verificar duplicados en el array antes de agregar un nuevo valor.
    function addToArray(uint256[] storage list, uint256 value) private {
        uint256 index = find(list, value);
        if (index == list.length) { // Si el valor no está en el array
            list.push(value);
        }
    }

// Eliminar un valor del array.
    function removeFromArray(uint256[] storage list, uint256 value) private {
        uint256 index = find(list, value);
        if (index < list.length) { // Si el valor está en el array
            list[index] = list[list.length - 1];
            list.pop();
        }
    }

// Buscar un valor en un array y retornar su índice o la longitud del array si no se encuentra.
    function find(uint256[] storage list, uint256 value) private view returns (uint256) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == value) {
                return i;
            }
        }
        return list.length;
    }


    // NOT SUPPORTED FUNCTIONS

// Funciones para deshabilitar las transferencias de NFTs,

    function transferFrom(address, address, uint256) 
        public 
        pure
        override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256) 
        public pure override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256,  bytes memory) 
        public 
        pure
        override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }


    // Compliance required by Solidity

// Funciones para asegurar que el contrato cumple con los estándares requeridos por ERC721 y ERC721Enumerable.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal 
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
   
}

