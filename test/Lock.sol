// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "../src/Lock.sol";
// import "../src/errors/Errors.sol";
// import "./SetUp.sol";

// contract LockTest is Test, SetUp {
//     uint256 constant AMOUNT = 1 ether;

//     event TokenLocked(
//         address token,
//         address account,
//         uint256 amount,
//         uint256 lockTime
//     );

//     event TokenUnlocked(address token, address account, uint256 amount);

//     function setUp() public override {
//         super.setUp();
//         CreateBondingCurve(CREATOR);
//     }

//     function lock(address account, uint256 amount) internal returns (uint256) {
//         // 하나의 prank 블록 안에서 모든 작업 수행
//         vm.startPrank(account);
//         vm.deal(account, amount + (amount / 100)); // amount + 1% 수수료
//         Buy(account, amount); // 토큰 구매

//         uint256 tokenAmount = MEME_TOKEN.balanceOf(account);

//         // Lock 컨트랙트에 토큰 전송 전 승인
//         MEME_TOKEN.approve(address(LOCK), tokenAmount);
//         MEME_TOKEN.transfer(address(LOCK), tokenAmount);

//         // 토큰 잠금
//         LOCK.lock(address(MEME_TOKEN), account);
//         vm.stopPrank(); // prank 종료

//         return tokenAmount;
//     }

//     function testBasicLock() public {
//         uint256 amount = lock(TRADER_A, AMOUNT);

//         // Verify token transfer
//         assertEq(
//             MEME_TOKEN.balanceOf(address(LOCK)),
//             amount,
//             "Lock contract should hold tokens"
//         );
//         assertEq(
//             MEME_TOKEN.balanceOf(TRADER_A),
//             0,
//             "Trader should have no tokens"
//         );

//         // Verify lock data
//         (
//             uint256 lockAmount,
//             uint256 lockTime,
//             uint256 listingTime
//         ) = LOCK.getLocked(address(MEME_TOKEN), TRADER_A)[0];

//         assertEq(lockAmount, amount, "Lock amount should match");
//         assertEq(
//             lockTime,
//             block.timestamp + DEFAULT_LOCK_TIME,
//             "Lock time should be set"
//         );
//         assertEq(listingTime, 0, "Listing time should be 0");
//     }

//     function testListingBasedUnlock() public {
//         uint256 amount = lock(TRADER_A, AMOUNT);

//         // Try unlocking before listing
//         vm.startPrank(TRADER_A);
//         vm.expectRevert(ERR_LOCK_NOT_UNLOCKABLE);
//         LOCK.unlock(address(MEME_TOKEN));
//         vm.stopPrank();

//         // Set listing time
//         vm.prank(OWNER);
//         LOCK.setListingTime(address(MEME_TOKEN), block.timestamp);

//         // Move time past lock period
//         vm.warp(block.timestamp + DEFAULT_LOCK_TIME);

//         // Unlock tokens
//         vm.startPrank(TRADER_A);
//         LOCK.unlock(address(MEME_TOKEN));

//         // Verify unlock
//         assertEq(
//             MEME_TOKEN.balanceOf(TRADER_A),
//             amount,
//             "Trader should receive tokens"
//         );
//         assertEq(
//             MEME_TOKEN.balanceOf(address(LOCK)),
//             0,
//             "Lock should have no tokens"
//         );
//         vm.stopPrank();
//     }

//     function testMultipleLocks() public {
//         uint256 firstAmount = lock(TRADER_A, AMOUNT);
//         vm.warp(block.timestamp + 1 days);
//         uint256 secondAmount = lock(TRADER_A, AMOUNT);

//         assertEq(
//             LOCK.getLocked(address(MEME_TOKEN), TRADER_A).length,
//             2,
//             "Should have two locks"
//         );

//         (
//             uint256 firstLockAmount,
//             uint256 firstLockTime,
//             uint256 firstListingTime
//         ) = LOCK.getLocked(address(MEME_TOKEN), TRADER_A)[0];

//         (
//             uint256 secondLockAmount,
//             uint256 secondLockTime,
//             uint256 secondListingTime
//         ) = LOCK.getLocked(address(MEME_TOKEN), TRADER_A)[1];

//         assertEq(firstLockAmount, firstAmount, "First lock amount should match");
//         assertEq(secondLockAmount, secondAmount, "Second lock amount should match");
//         assertTrue(
//             firstLockTime < secondLockTime,
//             "Second lock should be later"
//         );
//     }

//     function testTimeBasedUnlock() public {
//         uint256 amount = lock(TRADER_A, AMOUNT);

//         // Try unlocking before time
//         vm.startPrank(TRADER_A);
//         vm.expectRevert(ERR_LOCK_NOT_UNLOCKABLE);
//         LOCK.unlock(address(MEME_TOKEN));

//         // Move time past lock period
//         vm.warp(block.timestamp + DEFAULT_LOCK_TIME);

//         // Set listing time
//         vm.stopPrank();
//         vm.prank(OWNER);
//         LOCK.setListingTime(address(MEME_TOKEN), block.timestamp - 1 days);

//         // Unlock tokens
//         vm.prank(TRADER_A);
//         LOCK.unlock(address(MEME_TOKEN));

//         // Verify unlock
//         assertEq(
//             MEME_TOKEN.balanceOf(TRADER_A),
//             amount,
//             "Trader should receive tokens"
//         );
//         assertEq(
//             MEME_TOKEN.balanceOf(address(LOCK)),
//             0,
//             "Lock should have no tokens"
//         );
//     }

//     function testPartialUnlock() public {
//         // Lock tokens in two separate transactions
//         uint256 firstAmount = lock(TRADER_A, AMOUNT);
//         vm.warp(block.timestamp + 1 days);
//         uint256 secondAmount = lock(TRADER_A, AMOUNT);

//         // Move time past first lock period
//         vm.warp(block.timestamp + DEFAULT_LOCK_TIME);

//         // Set listing time
//         vm.prank(OWNER);
//         LOCK.setListingTime(address(MEME_TOKEN), block.timestamp);

//         // Unlock first batch
//         vm.startPrank(TRADER_A);
//         LOCK.unlock(address(MEME_TOKEN));

//         // Verify partial unlock
//         assertEq(
//             MEME_TOKEN.balanceOf(TRADER_A),
//             firstAmount,
//             "Should receive first locked amount"
//         );
//         assertEq(
//             MEME_TOKEN.balanceOf(address(LOCK)),
//             secondAmount,
//             "Lock should hold second amount"
//         );
//         vm.stopPrank();
//     }

//     function testUnauthorizedUnlock() public {
//         lock(TRADER_A, AMOUNT);
//         vm.warp(block.timestamp + DEFAULT_LOCK_TIME);

//         // Try unlocking as different user
//         vm.startPrank(TRADER_B);
//         vm.expectRevert(ERR_LOCK_UNAUTHORIZED);
//         LOCK.unlock(address(MEME_TOKEN));
//         vm.stopPrank();
//     }

//     function testLockEvents() public {
//         uint256 amount = AMOUNT;
//         Buy(TRADER_A, amount);

//         vm.startPrank(TRADER_A);
//         uint256 tokenAmount = MEME_TOKEN.balanceOf(TRADER_A);
//         MEME_TOKEN.approve(address(LOCK), tokenAmount);
//         MEME_TOKEN.transfer(address(LOCK), tokenAmount);

//         vm.expectEmit(true, true, true, true);
//         emit TokenLocked(
//             address(MEME_TOKEN),
//             TRADER_A,
//             tokenAmount,
//             block.timestamp + DEFAULT_LOCK_TIME
//         );
//         LOCK.lock(address(MEME_TOKEN), TRADER_A);
//         vm.stopPrank();

//         // Set listing time and move time forward
//         vm.prank(OWNER);
//         LOCK.setListingTime(address(MEME_TOKEN), block.timestamp);
//         vm.warp(block.timestamp + DEFAULT_LOCK_TIME);

//         // Test unlock event
//         vm.startPrank(TRADER_A);
//         vm.expectEmit(true, true, true, true);
//         emit TokenUnlocked(address(MEME_TOKEN), TRADER_A, tokenAmount);
//         LOCK.unlock(address(MEME_TOKEN));
//         vm.stopPrank();
//     }
// }
