// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "./TestUltils.sol";

contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool TransferInMintCallback;
        bool TransferInSwapCallback;
        bool mintLiquidity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            TransferInMintCallback: true,
            TransferInSwapCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;
        assertEq(
            poolBalance0,
            expectedAmount0,
            "Pool balance0 should be equal to expected amount0"
        );

        assertEq(
            poolBalance1,
            expectedAmount1,
            "Pool balance1 should be equal to expected amount1"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            expectedAmount0,
            "Pool token0 balance should be equal to expected amount0"
        );

        assertEq(
            token1.balanceOf(address(pool)),
            expectedAmount1,
            "Pool token1 balance should be equal to expected amount1"
        );

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(
            posLiquidity,
            params.liquidity,
            "Position liquidity should be equal to expected liquidity"
        );

        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
            params.lowerTick
        );
        assertTrue(tickInitialized, "Lower tick should be initialized");
        assertEq(
            tickLiquidity,
            params.liquidity,
            "Lower tick liquidity should be equal to expected liquidity"
        );

        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(tickInitialized, "Upper tick should be initialized");
        assertEq(
            tickLiquidity,
            params.liquidity,
            "Upper tick liquidity should be equal to expected liquidity"
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            params.currentSqrtP,
            "Pool sqrtPriceX96 should be equal to expected sqrtPriceX96"
        );

        assertEq(
            tick,
            params.currentTick,
            "Pool tick should be equal to expected tick"
        );

        assertEq(
            pool.liquidity(),
            params.liquidity,
            "Pool liquidity should be equal to expected liquidity"
        );
    }

    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            TransferInMintCallback: true,
            TransferInSwapCallback: true,
            mintLiquidity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setUpTestCase(params);

        uint256 swapAmount = 42 ether;
        token1.mint(address(this), swapAmount);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));

        UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: address(this)
        });

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            abi.encode(extra)
        );

        assertEq(
            amount0Delta,
            -0.008396714242162444 ether,
            "Swap amount0Delta should be equal to 0"
        );

        assertEq(
            amount1Delta,
            42 ether,
            "Swap amount1Delta should be equal to 0"
        );

        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta),
            "User balance0 should be equal to expected balance0"
        );

        assertEq(
            token1.balanceOf(address(this)),
            0,
            "User balance1 should be equal to expected balance1"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + amount0Delta),
            "Pool balance0 should be equal to expected balance0"
        );

        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + amount1Delta),
            "Pool balance1 should be equal to expected balance1"
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();

        assertEq(
            sqrtPriceX96,
            5604469350942327889444743441197,
            "invalid current sqrtP"
        );
        assertEq(tick, 85184, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function test_TickToSmall() public {
        // TestCaseParams memory params = TestCaseParams({
        //     wethBalance: 0,
        //     usdcBalance: 0,
        //     currentTick: 0,
        //     lowerTick: -887273,
        //     upperTick: 0,
        //     liquidity: 0,
        //     currentSqrtP: 1517882343751509868544,
        //     TransferInMintCallback: true,
        //     mintLiquidity: true
        // });

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), -887273, 0, 1517882343751509868544, "");
    }

    function test_ZeroLiquidity() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        pool.mint(address(this), 0, 6, 0, "");
    }

    function test_InsufficientInputAmount() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0,
            usdcBalance: 0,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            TransferInMintCallback: false,
            TransferInSwapCallback: false,
            mintLiquidity: false
        });
        setUpTestCase(params);
        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            params.liquidity,
            ""
        );
    }

    function setUpTestCase(
        TestCaseParams memory params
    ) internal returns (uint256 poolBalance0, uint256 poolBalance1) {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        if (params.mintLiquidity) {

            UniswapV3Pool.CallbackData memory extra = UniswapV3Pool
                .CallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    payer: address(this)
                });

            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity,
                abi.encode(extra)
            );
        }

        transferInMintCallback = params.TransferInMintCallback;
        transferInSwapCallback = params.TransferInSwapCallback;
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        if (transferInMintCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (UniswapV3Pool.CallbackData)
            );

            IERC20(extra.token0).transfer(msg.sender, amount0);
            IERC20(extra.token1).transfer(msg.sender, amount1);
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external {
        if (transferInSwapCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (UniswapV3Pool.CallbackData)
            );

            if (amount0 > 0) {
                IERC20(extra.token0).transfer(msg.sender, uint256(amount0));
            }

            if (amount1 > 0) {
                IERC20(extra.token1).transfer(msg.sender, uint256(amount1));
            }
        }
    }
}
