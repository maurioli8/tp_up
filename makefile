# Makefile para el proyecto CCNFT
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/GDVvYVzjQxOI0CHTA6TwI
PRIVATE_KEY=02561219f9e9a12ce38d9cf6779cfe054dce1b0aea502bd1945f85085c02885cd
DEPLOYER_ADDRESS=0x6bE8F3a97423fc9F2E18d1D9C5699833B74e5dD0
ETHERSCAN_API_KEY=3PZQ8KUTW39M4FII18KXR85SX2SUW6Y2X9

# Comando para desplegar el contrato BUSD
deploy-busd:
	@echo "Desplegando contrato BUSD..."
	forge script script/DeployBUSD.s.sol:DeployBUSD --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvv

# Variables necesarias para verificación e interacción
BUSD_ADDRESS=0xBusdContrato
CCNFT_ADDRESS=0xD1234D4BE496FE0FBf4e6DCbe61dBfF333E65e11
FEES_COLLECTOR=0xaddress1
FUNDS_COLLECTOR=0xaddress2


# Variables
-include .env
export

# Comandos básicos
.PHONY: help install build test clean

help:
	@echo "Comandos disponibles:"
	@echo "  install     - Instalar dependencias"
	@echo "  build       - Compilar contratos"
	@echo "  test        - Ejecutar tests"
	@echo "  clean       - Limpiar archivos compilados"
	@echo "  deploy      - Desplegar en Sepolia"
	@echo "  verify      - Verificar contratos en Etherscan"
	@echo "  fund        - Enviar ETH de prueba"

install:
	@echo "Instalando OpenZeppelin..."
	forge install OpenZeppelin/openzeppelin-contracts@v4.5.0 --no-commit
	@echo "Instalando forge-std..."
	forge install foundry-rs/forge-std --no-commit

build:
	@echo "Compilando contratos..."
	forge build

test:
	@echo "Ejecutando tests..."
	forge test -vvv

clean:
	@echo "Limpiando archivos compilados..."
	forge clean
# Comandos de despliegue y verificación
deploy:
	@echo "Desplegando en Sepolia..."
	forge script script/DeployCCNFT.s.sol:DeployCCNFT --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvv
	forge script script/DeployBUSD.s.sol:DeployBUSD --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify -vvvv

verify-busd:
	@echo "Verificando contrato BUSD..."
	forge verify-contract $(BUSD_ADDRESS) src/BUSD.sol:BUSD --chain sepolia --etherscan-api-key $(ETHERSCAN_API_KEY)

verify-ccnft:
	@echo "Verificando contrato CCNFT..."
	forge verify-contract $(CCNFT_ADDRESS) src/CCNFT.sol:CCNFT --chain sepolia --etherscan-api-key $(ETHERSCAN_API_KEY) --constructor-args $(shell cast abi-encode "constructor(address,string,string,string)" $(BUSD_ADDRESS) "Crypto College NFT" "CCNFT" "https://gateway.pinata.cloud/ipfs/YOUR_IPFS_HASH/")

# Comandos de utilidad
check-balance:
	@echo "Checking ETH balance..."
	cast balance $(DEPLOYER_ADDRESS) --rpc-url $(SEPOLIA_RPC_URL)

send-eth:
	@echo "Enviando ETH de prueba..."
	cast send $(DEPLOYER_ADDRESS) --value 0.1ether --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)

# Comandos de interacción con contratos
set-fees-collector:
	@echo "Setting fees collector..."
	cast send $(CCNFT_ADDRESS) "setFeesCollector(address)" $(FEES_COLLECTOR) --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)

set-funds-collector:
	@echo "Setting funds collector..."
	cast send $(CCNFT_ADDRESS) "setFundsCollector(address)" $(FUNDS_COLLECTOR) --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)

approve-busd:
	@echo "Approving BUSD for CCNFT..."
	cast send $(BUSD_ADDRESS) "approve(address,uint256)" $(CCNFT_ADDRESS) 10000000000000000000000000 --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)

buy-nft:
	@echo "Buying NFT..."
	cast send $(CCNFT_ADDRESS) "buy()" --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)

# Comandos de consulta
check-busd-balance:
	@echo "Checking BUSD balance..."
	cast call $(BUSD_ADDRESS) "balanceOf(address)" $(DEPLOYER_ADDRESS) --rpc-url $(SEPOLIA_RPC_URL)

check-nft-balance:
	@echo "Checking NFT balance..."
	cast call $(CCNFT_ADDRESS) "balanceOf(address)" $(DEPLOYER_ADDRESS) --rpc-url $(SEPOLIA_RPC_URL)

check-allowance:
	@echo "Checking BUSD allowance..."
	cast call $(BUSD_ADDRESS) "allowance(address,address)" $(DEPLOYER_ADDRESS) $(CCNFT_ADDRESS) --rpc-url $(SEPOLIA_RPC_URL)