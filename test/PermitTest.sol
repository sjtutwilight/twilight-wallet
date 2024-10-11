// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
//import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "contracts/SimpleAave/AToken.sol";
import "contracts/SimpleAave/LendingPool.sol";
import "contracts/Pokemon/PKMToken.sol";
import "contracts/utils/copyFromAave/WadRayMath.sol";
contract PermitTest is Test {
    using ECDSA for bytes32;

    LendingPool pool;
    AToken aToken;
    PKMToken pkm;
    address deployer;
    address user1;
    address user2;
    uint256 chainId;
    uint256 constant MAX_UINT_AMOUNT = type(uint256).max;
    string constant EIP712_REVISION = "1";

    function setUp() public {
        chainId = block.chainid;

        // 初始化账户
        deployer = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        // 假设已部署的合约地址（需要根据实际情况替换）
        // 也可以在这里部署 Mock 合约
        // dai = IERC20(DAI_ADDRESS);
        // pool = IPool(POOL_ADDRESS);
        // aDai = AToken(aDAI_ADDRESS);
        pool = new LendingPool();
        pkm = new PKMToken(100);
        aToken = new AToken();
        aToken.initialize(address(pool), address(pkm), "apkm", "apkm");

        // 部署者铸造 DAI 并存入池中，获得 aDAI
        vm.startPrank(address(pool));
        aToken.mint(user1, 10, WadRayMath.ray());
        vm.stopPrank();
    }

    function testDomainSeparator() public {
        bytes32 separator = aToken.DOMAIN_SEPARATOR();

        bytes32 expectedSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(aToken.name())),
                keccak256(bytes(EIP712_REVISION)),
                chainId,
                address(aToken)
            )
        );

        assertEq(separator, expectedSeparator, "Invalid domain separator");
    }

    //     function testPermitWithZeroExpiration() public {
    //         vm.startPrank(user1);

    //         uint256 nonce = aDai.nonces(deployer);
    //         uint256 amount = 2 ether;
    //         uint256 deadline = 0;

    //         bytes32 digest = _buildDigest(deployer, user1, amount, nonce, deadline);

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );

    //         vm.expectRevert(bytes("INVALID_EXPIRATION"));
    //         aDai.permit(deployer, user1, amount, deadline, v, r, s);

    //         vm.stopPrank();
    //     }

    //     function testPermitWithMaxExpiration() public {
    //         vm.startPrank(user1);

    //         uint256 nonce = aDai.nonces(deployer);
    //         uint256 amount = 2 ether;
    //         uint256 deadline = MAX_UINT_AMOUNT;

    //         bytes32 digest = _buildDigest(deployer, user1, amount, nonce, deadline);

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );

    //         aDai.permit(deployer, user1, amount, deadline, v, r, s);

    //         uint256 newNonce = aDai.nonces(deployer);
    //         assertEq(newNonce, nonce + 1, "Nonce not incremented");

    //         vm.stopPrank();
    //     }

    //     function testCancelPermit() public {
    //         vm.startPrank(user1);

    //         // 首先授予许可
    //         uint256 nonce = aDai.nonces(deployer);
    //         uint256 amount = 2 ether;
    //         uint256 deadline = MAX_UINT_AMOUNT;

    //         bytes32 digest = _buildDigest(deployer, user1, amount, nonce, deadline);

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );
    //         aDai.permit(deployer, user1, amount, deadline, v, r, s);

    //         // 取消许可
    //         nonce = aDai.nonces(deployer);
    //         amount = 0;

    //         digest = _buildDigest(deployer, user1, amount, nonce, deadline);

    //         (v, r, s) = vm.sign(uint256(uint160(deployer)), digest);
    //         aDai.permit(deployer, user1, amount, deadline, v, r, s);

    //         uint256 allowance = aDai.allowance(deployer, user1);
    //         assertEq(allowance, amount, "Allowance not zeroed");

    //         vm.stopPrank();
    //     }

    //     function testPermitWithInvalidNonce() public {
    //         vm.startPrank(user1);

    //         uint256 invalidNonce = 1000;
    //         uint256 amount = 2 ether;
    //         uint256 deadline = MAX_UINT_AMOUNT;

    //         bytes32 digest = _buildDigest(
    //             deployer,
    //             user1,
    //             amount,
    //             invalidNonce,
    //             deadline
    //         );

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );

    //         vm.expectRevert(bytes("INVALID_SIGNATURE"));
    //         aDai.permit(deployer, user1, amount, deadline, v, r, s);

    //         vm.stopPrank();
    //     }

    //     function testPermitWithInvalidExpiration() public {
    //         vm.startPrank(user1);

    //         uint256 nonce = aDai.nonces(deployer);
    //         uint256 amount = 2 ether;
    //         uint256 deadline = 1; // 过去的时间

    //         bytes32 digest = _buildDigest(deployer, user1, amount, nonce, deadline);

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );

    //         vm.expectRevert(bytes("INVALID_EXPIRATION"));
    //         aDai.permit(deployer, user1, amount, deadline, v, r, s);

    //         vm.stopPrank();
    //     }

    //     function testPermitWithInvalidSignature() public {
    //         vm.startPrank(user1);

    //         uint256 nonce = aDai.nonces(deployer);
    //         uint256 amount = 2 ether;
    //         uint256 deadline = MAX_UINT_AMOUNT;

    //         // 使用错误的 spender 地址构建签名
    //         bytes32 digest = _buildDigest(
    //             deployer,
    //             address(0), // 无效的 spender
    //             amount,
    //             nonce,
    //             deadline
    //         );

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );

    //         vm.expectRevert(bytes("INVALID_SIGNATURE"));
    //         aDai.permit(deployer, address(0), amount, deadline, v, r, s);

    //         vm.stopPrank();
    //     }

    //     function testPermitWithInvalidOwner() public {
    //         vm.startPrank(user1);

    //         uint256 nonce = aDai.nonces(address(0)); // 无效的 owner
    //         uint256 amount = 2 ether;
    //         uint256 deadline = MAX_UINT_AMOUNT;

    //         bytes32 digest = _buildDigest(
    //             address(0), // 无效的 owner
    //             user1,
    //             amount,
    //             nonce,
    //             deadline
    //         );

    //         // 无法签名无效地址，这里使用 deployer 的私钥，但应该失败
    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    //             uint256(uint160(deployer)),
    //             digest
    //         );

    //         vm.expectRevert(bytes("ZERO_ADDRESS_NOT_VALID"));
    //         aDai.permit(address(0), user1, amount, deadline, v, r, s);

    //         vm.stopPrank();
    //     }

    //     function _buildDigest(
    //         address owner,
    //         address spender,
    //         uint256 value,
    //         uint256 nonce,
    //         uint256 deadline
    //     ) internal view returns (bytes32) {
    //         bytes32 structHash = keccak256(
    //             abi.encode(
    //                 keccak256(
    //                     "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    //                 ),
    //                 owner,
    //                 spender,
    //                 value,
    //                 nonce,
    //                 deadline
    //             )
    //         );

    //         return
    //             keccak256(
    //                 abi.encodePacked(
    //                     "\x19\x01",
    //                     aDai.DOMAIN_SEPARATOR(),
    //                     structHash
    //                 )
    //             );
    //     }
    // }

    // // 以下是用于测试的 Mock 合约（需要根据实际情况替换）
    // contract ERC20Mock is ERC20 {
    //     constructor() ERC20("Mock DAI", "mDAI") {}

    //     function mint(address to, uint256 amount) external {
    //         _mint(to, amount);
    //     }
    // }

    // contract ATokenMock is AToken {
    //     constructor(
    //         address underlyingAsset,
    //         string memory name,
    //         string memory symbol,
    //         IPool pool_
    //     ) AToken(pool_, underlyingAsset, name, symbol) {}

    // 需要实现必要的函数和逻辑
}
