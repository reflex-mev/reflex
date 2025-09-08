// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@reflex/integrations/algebra/full/BasePluginV3Factory.sol";
import "@reflex/integrations/algebra/full/AlgebraBasePluginV3.sol";
import "@reflex/integrations/algebra/interfaces/IBasePluginV3Factory.sol";
import "@reflex/interfaces/IReflexRouter.sol";
import "../../../utils/TestUtils.sol";
import "../../../mocks/MockToken.sol";
import "../../../mocks/MockAlgebraFactory.sol";
import "../../../mocks/MockReflexRouter.sol";
import "../../../mocks/MockPool.sol";

contract BasePluginV3FactoryTest is Test {
    BasePluginV3Factory public factory;
    MockAlgebraFactory public algebraFactory;
    MockReflexRouter public reflexRouter;
    MockToken public token0;
    MockToken public token1;
    MockPool public pool;

    address public admin = address(0x1);
    address public nonAdmin = address(0x2);
    address public poolsAdmin = address(0x3);
    address public alice = address(0xA);
    address public newReflexRouter = address(0x999);

    // Events from IBasePluginV2Factory
    event FarmingAddress(address indexed newFarmingAddress);
    event DefaultBaseFee(uint16 newDefaultBaseFee);

    function setUp() public {
        // Create mock tokens
        token0 = MockToken(TestUtils.createMockToken("Token0", "TK0", 1000000 * 10 ** 18));
        token1 = MockToken(TestUtils.createMockToken("Token1", "TK1", 1000000 * 10 ** 18));

        // Ensure token0 < token1 for consistent ordering
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Create mock Algebra factory
        algebraFactory = MockAlgebraFactory(TestUtils.createMockAlgebraFactory());
        algebraFactory.setOwner(admin);
        algebraFactory.grantRole(algebraFactory.ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR(), admin);
        algebraFactory.grantRole(algebraFactory.POOLS_ADMINISTRATOR_ROLE(), poolsAdmin);

        // Create mock pool
        pool = MockPool(TestUtils.createMockPool(address(token0), address(token1), address(algebraFactory)));
        algebraFactory.setPoolByPair(address(token0), address(token1), address(pool));

        // Create mock Reflex router
        reflexRouter = MockReflexRouter(TestUtils.createSimpleMockReflexRouter(admin));

        // Deploy BasePluginV3Factory
        factory = new BasePluginV3Factory(address(algebraFactory));

        // Set initial reflex router
        vm.prank(admin);
        factory.setReflexRouter(address(reflexRouter));
    }

    // ========== Constructor Tests ==========

    function testConstructor() public {
        BasePluginV3Factory newFactory = new BasePluginV3Factory(address(algebraFactory));

        assertEq(newFactory.algebraFactory(), address(algebraFactory));
        assertEq(newFactory.defaultBaseFee(), 3000);
        assertEq(newFactory.farmingAddress(), address(0));
        assertEq(newFactory.reflexRouter(), address(0));
    }

    function testConstructorWithZeroFactory() public {
        // Should not revert - the contract allows zero factory address
        BasePluginV3Factory newFactory = new BasePluginV3Factory(address(0));
        assertEq(newFactory.algebraFactory(), address(0));
    }

    // ========== Access Control Tests ==========

    function testOnlyAdministratorModifier() public {
        // Admin should be able to call admin functions
        vm.prank(admin);
        factory.setDefaultBaseFee(4000);

        // Non-admin should not be able to call admin functions
        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setDefaultBaseFee(5000);
    }

    function testFactoryOwnerCanCallAdminFunctions() public {
        vm.prank(admin);
        factory.setDefaultBaseFee(4000);

        assertEq(factory.defaultBaseFee(), 4000);
    }

    // ========== Reflex Router Tests ==========

    function testSetReflexRouter() public {
        address newRouter = address(0x123);

        vm.prank(admin);
        factory.setReflexRouter(newRouter);

        assertEq(factory.reflexRouter(), newRouter);
    }

    function testSetReflexRouterUnauthorized() public {
        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setReflexRouter(newReflexRouter);
    }

    function testSetReflexRouterToZero() public {
        vm.prank(admin);
        factory.setReflexRouter(address(0));

        assertEq(factory.reflexRouter(), address(0));
    }

    function testReflexRouterInitiallyZero() public {
        BasePluginV3Factory newFactory = new BasePluginV3Factory(address(algebraFactory));
        assertEq(newFactory.reflexRouter(), address(0));
    }

    // ========== Plugin Creation Tests ==========

    function testBeforeCreatePoolHook() public {
        address mockPool = address(0x456);

        vm.prank(address(algebraFactory));
        address plugin =
            factory.beforeCreatePoolHook(mockPool, address(token0), address(token1), address(0), address(0), "");

        assertTrue(plugin != address(0));
        assertEq(factory.pluginByPool(mockPool), plugin);

        // Verify the plugin was created with correct parameters
        AlgebraBasePluginV3 createdPlugin = AlgebraBasePluginV3(plugin);
        assertEq(createdPlugin.pool(), mockPool);
        // Note: factory and pluginFactory are internal/immutable and not directly accessible via getters
    }

    function testBeforeCreatePoolHookUnauthorized() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        factory.beforeCreatePoolHook(address(pool), address(token0), address(token1), address(0), address(0), "");
    }

    function testAfterCreatePoolHook() public {
        vm.prank(address(algebraFactory));
        factory.afterCreatePoolHook(address(pool), address(token0), address(token1));
        // Should not revert, just a view function that checks sender
    }

    function testAfterCreatePoolHookUnauthorized() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        factory.afterCreatePoolHook(address(pool), address(token0), address(token1));
    }

    function testCreatePluginForExistingPool() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        assertTrue(plugin != address(0));
        assertEq(factory.pluginByPool(address(pool)), plugin);

        // Verify the plugin was created with correct parameters
        AlgebraBasePluginV3 createdPlugin = AlgebraBasePluginV3(plugin);
        assertEq(createdPlugin.pool(), address(pool));
        // Note: factory and pluginFactory are internal/immutable and not directly accessible via getters
    }

    function testCreatePluginForExistingPoolUnauthorized() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        factory.createPluginForExistingPool(address(token0), address(token1));
    }

    function testCreatePluginForNonExistentPool() public {
        MockToken token2 = MockToken(TestUtils.createMockToken("Token2", "TK2", 1000000 * 10 ** 18));
        MockToken token3 = MockToken(TestUtils.createMockToken("Token3", "TK3", 1000000 * 10 ** 18));

        vm.prank(poolsAdmin);
        vm.expectRevert("Pool not exist");
        factory.createPluginForExistingPool(address(token2), address(token3));
    }

    function testCreatePluginTwiceForSamePool() public {
        // Create plugin first time
        vm.prank(poolsAdmin);
        factory.createPluginForExistingPool(address(token0), address(token1));

        // Try to create again - should revert
        vm.prank(poolsAdmin);
        vm.expectRevert("Already created");
        factory.createPluginForExistingPool(address(token0), address(token1));
    }

    // ========== Plugin Creation with Reflex Router Tests ==========

    function testPluginCreatedWithReflexRouter() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV3 createdPlugin = AlgebraBasePluginV3(plugin);
        assertEq(createdPlugin.getReflexAdmin(), reflexRouter.getReflexAdmin());
    }

    function testPluginCreatedWithZeroReflexRouter() public {
        // Set reflex router to zero
        vm.prank(admin);
        factory.setReflexRouter(address(0));

        // Create a new pool for this test
        MockToken token2 = MockToken(TestUtils.createMockToken("Token2", "TK2", 1000000 * 10 ** 18));
        MockToken token3 = MockToken(TestUtils.createMockToken("Token3", "TK3", 1000000 * 10 ** 18));
        MockPool pool2 = MockPool(TestUtils.createMockPool(address(token2), address(token3), address(algebraFactory)));
        algebraFactory.setPoolByPair(address(token2), address(token3), address(pool2));

        // Plugin creation should fail because ReflexAfterSwap requires non-zero router
        vm.prank(poolsAdmin);
        vm.expectRevert("Invalid router address");
        factory.createPluginForExistingPool(address(token2), address(token3));
    }

    function testPluginCreatedAfterReflexRouterChange() public {
        // Change reflex router
        MockReflexRouter newRouter = MockReflexRouter(TestUtils.createSimpleMockReflexRouter(alice));
        vm.prank(admin);
        factory.setReflexRouter(address(newRouter));

        // Create a new pool for this test
        MockToken token2 = MockToken(TestUtils.createMockToken("Token2", "TK2", 1000000 * 10 ** 18));
        MockToken token3 = MockToken(TestUtils.createMockToken("Token3", "TK3", 1000000 * 10 ** 18));
        MockPool pool2 = MockPool(TestUtils.createMockPool(address(token2), address(token3), address(algebraFactory)));
        algebraFactory.setPoolByPair(address(token2), address(token3), address(pool2));

        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token2), address(token3));

        AlgebraBasePluginV3 createdPlugin = AlgebraBasePluginV3(plugin);
        assertEq(createdPlugin.getReflexAdmin(), newRouter.getReflexAdmin());
    }

    // ========== Default Base Fee Tests ==========

    function testSetDefaultBaseFee() public {
        uint16 newFee = 4000;

        vm.expectEmit(true, true, true, true);
        emit DefaultBaseFee(newFee);

        vm.prank(admin);
        factory.setDefaultBaseFee(newFee);

        assertEq(factory.defaultBaseFee(), newFee);
    }

    function testSetDefaultBaseFeeSameValue() public {
        uint16 currentFee = factory.defaultBaseFee();

        vm.prank(admin);
        vm.expectRevert();
        factory.setDefaultBaseFee(currentFee);
    }

    function testSetDefaultBaseFeeUnauthorized() public {
        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setDefaultBaseFee(4000);
    }

    function testPluginCreatedWithCorrectBaseFee() public {
        uint16 customFee = 5000;

        vm.prank(admin);
        factory.setDefaultBaseFee(customFee);

        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV3 createdPlugin = AlgebraBasePluginV3(plugin);
        assertEq(createdPlugin.s_baseFee(), customFee);
    }

    // ========== Farming Address Tests ==========

    function testSetFarmingAddress() public {
        address newFarmingAddress = address(0x789);

        vm.prank(admin);
        factory.setFarmingAddress(newFarmingAddress);

        assertEq(factory.farmingAddress(), newFarmingAddress);
    }

    function testSetFarmingAddressSameValue() public {
        address currentFarmingAddress = factory.farmingAddress();

        vm.prank(admin);
        vm.expectRevert();
        factory.setFarmingAddress(currentFarmingAddress);
    }

    function testSetFarmingAddressUnauthorized() public {
        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setFarmingAddress(address(0x789));
    }

    // ========== Integration Tests ==========

    function testPluginCreationWithAllParameters() public {
        address newFarmingAddress = address(0x789);
        uint16 newBaseFee = 4000;
        MockReflexRouter newRouter = MockReflexRouter(TestUtils.createSimpleMockReflexRouter(alice));

        // Set all parameters
        vm.startPrank(admin);
        factory.setFarmingAddress(newFarmingAddress);
        factory.setDefaultBaseFee(newBaseFee);
        factory.setReflexRouter(address(newRouter));
        vm.stopPrank();

        // Create plugin
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        // Verify all parameters
        AlgebraBasePluginV3 createdPlugin = AlgebraBasePluginV3(plugin);
        assertEq(createdPlugin.pool(), address(pool));
        assertEq(createdPlugin.s_baseFee(), newBaseFee);
        assertEq(createdPlugin.getReflexAdmin(), newRouter.getReflexAdmin());

        // Verify factory state
        assertEq(factory.farmingAddress(), newFarmingAddress);
        assertEq(factory.defaultBaseFee(), newBaseFee);
        assertEq(factory.reflexRouter(), address(newRouter));
        assertEq(factory.pluginByPool(address(pool)), plugin);
    }

    function testMultiplePluginCreation() public {
        // Create additional pools and tokens
        MockToken token2 = MockToken(TestUtils.createMockToken("Token2", "TK2", 1000000 * 10 ** 18));
        MockToken token3 = MockToken(TestUtils.createMockToken("Token3", "TK3", 1000000 * 10 ** 18));
        MockToken token4 = MockToken(TestUtils.createMockToken("Token4", "TK4", 1000000 * 10 ** 18));

        MockPool pool2 = MockPool(TestUtils.createMockPool(address(token2), address(token3), address(algebraFactory)));
        MockPool pool3 = MockPool(TestUtils.createMockPool(address(token2), address(token4), address(algebraFactory)));

        algebraFactory.setPoolByPair(address(token2), address(token3), address(pool2));
        algebraFactory.setPoolByPair(address(token2), address(token4), address(pool3));

        // Create multiple plugins
        vm.startPrank(poolsAdmin);
        address plugin1 = factory.createPluginForExistingPool(address(token0), address(token1));
        address plugin2 = factory.createPluginForExistingPool(address(token2), address(token3));
        address plugin3 = factory.createPluginForExistingPool(address(token2), address(token4));
        vm.stopPrank();

        // Verify all plugins are different and correctly mapped
        assertTrue(plugin1 != plugin2);
        assertTrue(plugin2 != plugin3);
        assertTrue(plugin1 != plugin3);

        assertEq(factory.pluginByPool(address(pool)), plugin1);
        assertEq(factory.pluginByPool(address(pool2)), plugin2);
        assertEq(factory.pluginByPool(address(pool3)), plugin3);
    }

    // ========== Edge Cases ==========

    function testConstants() public view {
        assertEq(
            factory.ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR(), keccak256("ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR")
        );
    }

    function testImmutableAlgebraFactory() public view {
        assertEq(factory.algebraFactory(), address(algebraFactory));

        // Cannot change immutable factory (this is just for documentation)
        assertTrue(factory.algebraFactory() == address(algebraFactory));
    }
}
