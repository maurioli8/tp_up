// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../script/CCNFT.sol";
import "../script/ERC20Mock.sol";

contract CCNFTTest is Test {
    CCNFT public ccnft;
    ERC20Mock public erc20;
    address public owner;
    address public user;
    address public fundsCollector;
    address public feesCollector;

    function setUp() public {
        owner = address(this);
        user = address(0xBEEF);
        fundsCollector = address(0xCAFE);
        feesCollector = address(0xFEE1);

        // Deploy mock ERC20 and mint tokens to user
        erc20 = new ERC20Mock("MockToken", "MTK", user, 1_000_000 ether);

        // Deploy CCNFT
        ccnft = new CCNFT("TestNFT", "TNFT");

        // Set parameters
        ccnft.setFundsToken(address(erc20));
        ccnft.setFundsCollector(fundsCollector);
        ccnft.setFeesCollector(feesCollector);
        ccnft.setCanBuy(true);
        ccnft.setCanClaim(true);
        ccnft.setCanTrade(true);
        ccnft.setMaxBatchCount(10);
        ccnft.setMaxValueToRaise(1_000_000 ether);
        ccnft.setBuyFee(100); // 1%
        ccnft.setTradeFee(100); // 1%
        ccnft.setProfitToPay(1000); // 10%
        ccnft.addValidValues(1 ether);

        // User approves CCNFT to spend tokens
        vm.prank(user);
        erc20.approve(address(ccnft), 100 ether);
    }

    function testBuyNFT() public {
        vm.prank(user);
        ccnft.buy(1 ether, 1);
        assertEq(ccnft.ownerOf(0), user);
    }

    function testClaimNFT() public {
        // Comprar NFT
        vm.prank(user);
        ccnft.buy(1 ether, 1);

        // Reclamar NFT
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;

         // Simular fondos en fundsCollector para el pago del claim
        erc20.mint(fundsCollector, 2 ether);

        // fundsCollector aprueba al contrato CCNFT para gastar sus tokens
        vm.prank(fundsCollector);
        erc20.approve(address(ccnft), 2 ether);

        // User reclama el NFT
        vm.prank(user);
        ccnft.claim(ids);

        // El NFT debe estar quemado (no debe existir)
        vm.expectRevert();
        ccnft.ownerOf(0);
    }

    function testPutOnSaleAndTrade() public {
        // Comprar NFT
        vm.prank(user);
        ccnft.buy(1 ether, 1);

        // User pone en venta el NFT
        vm.prank(user);
        ccnft.putOnSale(0, 2 ether);

        // addr2 compra el NFT en venta
        address buyer = address(0x1234);
        vm.prank(buyer);
        erc20.mint(buyer, 10 ether); // Asegúrate de que ERC20Mock tenga función mint, o transfiere desde owner
        vm.prank(buyer);
        erc20.approve(address(ccnft), 10 ether);

        vm.prank(buyer);
        ccnft.trade(0);

        // El nuevo dueño debe ser buyer
        assertEq(ccnft.ownerOf(0), buyer);
    }
    
}