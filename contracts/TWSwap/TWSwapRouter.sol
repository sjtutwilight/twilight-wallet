//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "./libraries/TWSwapLibrary.sol";
import "./interfaces/ITWSwapPair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
contract TWSwapRouter {
    using SafeERC20 for IERC20;

    address public immutable factory;
    constructor(address _factory) {
        factory = _factory;
    }
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "expired");
        _;
    }
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        if (ITWSwapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            console.log("111");
            ITWSwapFactory(factory).createPair(tokenA, tokenB);
        }
        console.log("start");
        (uint256 reserveA, uint256 reserveB) = TWSwapLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        console.log(reserveA);
        console.log(reserveB);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = TWSwapLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            console.log(amountBOptimal);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "insufficient b input");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = TWSwapLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                console.log(amountAOptimal);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "insufficient a input");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = TWSwapLibrary.pairFor(factory, tokenA, tokenB);
        console.log(pair);
        TWSwapLibrary.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TWSwapLibrary.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = ITWSwapPair(pair).mint(to);
    }
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = TWSwapLibrary.pairFor(factory, tokenA, tokenB);
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = ITWSwapPair(pair).burn(to);
        (address token0, ) = TWSwapLibrary.sortToken(tokenA, tokenB);
        (amountA, amountB) = (token0 == tokenA)
            ? (amount0, amount1)
            : (amount1, amount0);
        require(amountA >= amountAMin, "insufficent a amount");
        require(amountB >= amountBMin, "insufficent B amount");
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = TWSwapLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IERC20Permit(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address token0, ) = TWSwapLibrary.sortToken(path[i], path[i + 1]);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = path[i] == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i == path.length - 2
                ? _to
                : TWSwapLibrary.pairFor(factory, path[i + 1], path[i + 2]);
            console.log(to);
            console.log(amount1Out);
            console.log(amount0Out);
            console.log(TWSwapLibrary.pairFor(factory, path[i], path[i + 1]));
            ITWSwapPair(TWSwapLibrary.pairFor(factory, path[i], path[i + 1]))
                .swap(amount0Out, amount1Out, to);
        }
    }
    function swapTokenForExactToken(
        uint256 inputMax,
        uint256 output,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = TWSwapLibrary.getAmountsIn(factory, output, path);
        console.log(amounts[0]);
        console.log(amounts[1]);
        require(amounts[0] <= inputMax, "excessive input amount");
        TWSwapLibrary.safeTransferFrom(
            path[0],
            msg.sender,
            TWSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        console.log(
            IERC20(path[0]).balanceOf(
                TWSwapLibrary.pairFor(factory, path[0], path[1])
            )
        );
        _swap(amounts, path, to);
    }
    function swapExactTokenForToken(
        uint256 input,
        uint256 outputMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = TWSwapLibrary.getAmountsOut(factory, input, path);
        console.log(amounts[0]);
        console.log(amounts[1]);
        require(
            amounts[path.length - 1] >= outputMin,
            "insufficient output amount"
        );
        TWSwapLibrary.safeTransferFrom(
            path[0],
            msg.sender,
            TWSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }
}
