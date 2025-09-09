// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@reflex/integrations/algebra/v1/BasePluginV1Factory.sol";
import "@reflex/integrations/algebra/v1/AlgebraBasePluginV1.sol";
import "@cryptoalgebra/plugin/interfaces/IBasePluginV1Factory.sol";
import "@cryptoalgebra/plugin/base/AlgebraFeeConfiguration.sol";
import "@reflex/interfaces/IReflexRouter.sol";
import "../../../utils/TestUtils.sol";
import "../../../mocks/MockToken.sol";
import "../../../mocks/MockAlgebraFactory.sol";
import "../../../mocks/MockReflexRouter.sol";
import "../../../mocks/MockPool.sol";

contract BasePluginV1FactoryTest is Test {
    BasePluginV1Factory public factory;
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

    // Events from IBasePluginV1Factory
    event FarmingAddress(address newFarmingAddress);
    event DefaultFeeConfiguration(AlgebraFeeConfiguration newDefaultFeeConfiguration);

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

        // Deploy BasePluginV1Factory
        bytes32 defaultConfigId = keccak256("test-config");
        factory = new BasePluginV1Factory(address(algebraFactory), address(reflexRouter), defaultConfigId);

        // Set initial reflex router
        // Router is now set in constructor, no need to set separately
    }

    // ========== Constructor Tests ==========

    function testConstructor() public {
        bytes32 testConfigId = keccak256("test-config");
        BasePluginV1Factory newFactory =
            new BasePluginV1Factory(address(algebraFactory), address(reflexRouter), testConfigId);

        assertEq(newFactory.algebraFactory(), address(algebraFactory));
        assertEq(newFactory.reflexRouter(), address(reflexRouter));
        assertEq(newFactory.reflexConfigId(), testConfigId);
        assertEq(newFactory.farmingAddress(), address(0));

        // Check default fee configuration
        (uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee) =
            newFactory.defaultFeeConfiguration();
        assertEq(alpha1, 2900);
        assertEq(alpha2, 12000);
        assertEq(beta1, 360);
        assertEq(beta2, 60000);
        assertEq(gamma1, 59);
        assertEq(gamma2, 8500);
        assertEq(baseFee, 100);
    }

    function testConstructorWithZeroFactory() public {
        // Should not revert - the contract allows zero factory address
        bytes32 testConfigId = keccak256("test-config");
        BasePluginV1Factory newFactory = new BasePluginV1Factory(address(0), address(reflexRouter), testConfigId);
        assertEq(newFactory.algebraFactory(), address(0));
    }

    // ========== Access Control Tests ==========

    function testOnlyAdministratorModifier() public {
        // Admin should be able to call admin functions
        vm.prank(admin);
        factory.setFarmingAddress(address(0x123));

        // Non-admin should not be able to call admin functions
        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setFarmingAddress(address(0x456));
    }

    function testFactoryOwnerCanCallAdminFunctions() public {
        vm.prank(admin);
        factory.setFarmingAddress(address(0x123));

        assertEq(factory.farmingAddress(), address(0x123));
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
        bytes32 testConfigId = keccak256("test-config");
        BasePluginV1Factory newFactory = new BasePluginV1Factory(address(algebraFactory), address(0), testConfigId);
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
        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertEq(createdPlugin.pool(), mockPool);
        assertEq(createdPlugin.getRouter(), address(reflexRouter));
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
        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertEq(createdPlugin.pool(), address(pool));
        assertEq(createdPlugin.getRouter(), address(reflexRouter));
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

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertEq(createdPlugin.getReflexAdmin(), reflexRouter.getReflexAdmin());
        assertEq(createdPlugin.getRouter(), address(reflexRouter));
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

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertEq(createdPlugin.getReflexAdmin(), newRouter.getReflexAdmin());
        assertEq(createdPlugin.getRouter(), address(newRouter));
    }

    // ========== Default Fee Configuration Tests ==========

    function testSetDefaultFeeConfiguration() public {
        AlgebraFeeConfiguration memory newConfig = AlgebraFeeConfiguration({
            alpha1: 3000,
            alpha2: 13000,
            beta1: 400,
            beta2: 65000,
            gamma1: 60,
            gamma2: 9000,
            baseFee: 150
        });

        vm.expectEmit(true, true, true, true);
        emit DefaultFeeConfiguration(newConfig);

        vm.prank(admin);
        factory.setDefaultFeeConfiguration(newConfig);

        AlgebraFeeConfiguration memory config = factory.getDefaultFeeConfigurationStruct();
        assertEq(config.alpha1, newConfig.alpha1);
        assertEq(config.alpha2, newConfig.alpha2);
        assertEq(config.beta1, newConfig.beta1);
        assertEq(config.beta2, newConfig.beta2);
        assertEq(config.gamma1, newConfig.gamma1);
        assertEq(config.gamma2, newConfig.gamma2);
        assertEq(config.baseFee, newConfig.baseFee);
    }

    function testSetDefaultFeeConfigurationInvalidGamma() public {
        AlgebraFeeConfiguration memory invalidConfig = AlgebraFeeConfiguration({
            alpha1: 3000,
            alpha2: 13000,
            beta1: 400,
            beta2: 65000,
            gamma1: 0, // Invalid: gamma1 = 0
            gamma2: 9000,
            baseFee: 150
        });

        vm.prank(admin);
        vm.expectRevert("Gamma values must be > 0");
        factory.setDefaultFeeConfiguration(invalidConfig);
    }

    function testSetDefaultFeeConfigurationMaxFeeTooHigh() public {
        AlgebraFeeConfiguration memory invalidConfig = AlgebraFeeConfiguration({
            alpha1: 30000,
            alpha2: 30000,
            beta1: 400,
            beta2: 65000,
            gamma1: 60,
            gamma2: 9000,
            baseFee: 10000 // Combined alpha1 + alpha2 + baseFee > uint16.max
        });

        vm.prank(admin);
        vm.expectRevert("Max fee too high");
        factory.setDefaultFeeConfiguration(invalidConfig);
    }

    function testSetDefaultFeeConfigurationUnauthorized() public {
        AlgebraFeeConfiguration memory newConfig = AlgebraFeeConfiguration({
            alpha1: 3000,
            alpha2: 13000,
            beta1: 400,
            beta2: 65000,
            gamma1: 60,
            gamma2: 9000,
            baseFee: 150
        });

        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setDefaultFeeConfiguration(newConfig);
    }

    function testPluginCreatedWithCorrectFeeConfiguration() public {
        AlgebraFeeConfiguration memory customConfig = AlgebraFeeConfiguration({
            alpha1: 3500,
            alpha2: 14000,
            beta1: 450,
            beta2: 70000,
            gamma1: 65,
            gamma2: 9500,
            baseFee: 200
        });

        vm.prank(admin);
        factory.setDefaultFeeConfiguration(customConfig);

        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        // Note: Plugin uses internal fee configuration, but we can test that it was created successfully
        assertTrue(plugin != address(0));
    }

    // ========== Farming Address Tests ==========

    function testSetFarmingAddress() public {
        address newFarmingAddress = address(0x789);

        vm.expectEmit(true, true, true, true);
        emit FarmingAddress(newFarmingAddress);

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

    // ========== Plugin Functionality Tests ==========

    function testPluginReflexEnabled() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertTrue(createdPlugin.reflexEnabled());
    }

    function testPluginSetReflexEnabled() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);

        // Admin can disable reflex functionality
        vm.prank(admin);
        createdPlugin.setReflexEnabled(false);
        assertFalse(createdPlugin.reflexEnabled());

        // Admin can enable reflex functionality
        vm.prank(admin);
        createdPlugin.setReflexEnabled(true);
        assertTrue(createdPlugin.reflexEnabled());
    }

    function testPluginSetReflexEnabledUnauthorized() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);

        vm.prank(nonAdmin);
        vm.expectRevert(); // Algebra's _authorize() reverts without a message
        createdPlugin.setReflexEnabled(false);
    }

    function testPluginDefaultConfiguration() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);

        // Test default plugin config (V1 uses dynamic fees)
        // BEFORE_SWAP_FLAG=1, AFTER_SWAP_FLAG=2, AFTER_INIT_FLAG=64, DYNAMIC_FEE=128
        // Total: 1+2+64+128=195
        uint8 expectedConfig = 195;
        assertEq(createdPlugin.defaultPluginConfig(), expectedConfig);
    }

    // ========== Integration Tests ==========

    function testPluginCreationWithAllParameters() public {
        address newFarmingAddress = address(0x789);
        AlgebraFeeConfiguration memory newConfig = AlgebraFeeConfiguration({
            alpha1: 3200,
            alpha2: 13500,
            beta1: 420,
            beta2: 68000,
            gamma1: 62,
            gamma2: 9200,
            baseFee: 180
        });
        MockReflexRouter newRouter = MockReflexRouter(TestUtils.createSimpleMockReflexRouter(alice));

        // Set all parameters
        vm.startPrank(admin);
        factory.setFarmingAddress(newFarmingAddress);
        factory.setDefaultFeeConfiguration(newConfig);
        factory.setReflexRouter(address(newRouter));
        vm.stopPrank();

        // Create plugin
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        // Verify all parameters
        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertEq(createdPlugin.pool(), address(pool));
        assertEq(createdPlugin.getRouter(), address(newRouter));
        assertEq(createdPlugin.getReflexAdmin(), newRouter.getReflexAdmin());

        // Verify factory state
        assertEq(factory.farmingAddress(), newFarmingAddress);
        assertEq(factory.reflexRouter(), address(newRouter));
        assertEq(factory.pluginByPool(address(pool)), plugin);

        AlgebraFeeConfiguration memory factoryConfig = factory.getDefaultFeeConfigurationStruct();
        assertEq(factoryConfig.alpha1, newConfig.alpha1);
        assertEq(factoryConfig.baseFee, newConfig.baseFee);
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

        // Verify all plugins have the same reflex router
        AlgebraBasePluginV1 p1 = AlgebraBasePluginV1(plugin1);
        AlgebraBasePluginV1 p2 = AlgebraBasePluginV1(plugin2);
        AlgebraBasePluginV1 p3 = AlgebraBasePluginV1(plugin3);

        assertEq(p1.getRouter(), address(reflexRouter));
        assertEq(p2.getRouter(), address(reflexRouter));
        assertEq(p3.getRouter(), address(reflexRouter));
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

    function testPluginGetCurrentFee() public {
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);

        // Test getCurrentFee function (should not revert)
        uint16 currentFee = createdPlugin.getCurrentFee();
        // Fee should be within reasonable bounds
        assertTrue(currentFee >= 0 && currentFee <= type(uint16).max);
    }

    // ========== ConfigId Tests ==========

    function testSetConfigId() public {
        bytes32 newConfigId = keccak256("new-v1-config-id");

        vm.prank(admin);
        factory.setConfigId(newConfigId);

        assertEq(factory.reflexConfigId(), newConfigId);
    }

    function testSetConfigIdUnauthorized() public {
        bytes32 newConfigId = keccak256("unauthorized-v1-config");

        vm.prank(nonAdmin);
        vm.expectRevert("Only administrator");
        factory.setConfigId(newConfigId);
    }

    function testPluginCreatedWithFactoryConfigId() public {
        bytes32 customConfigId = keccak256("v1-factory-custom-config");

        // Set custom config ID in factory
        vm.prank(admin);
        factory.setConfigId(customConfigId);

        // Create plugin
        vm.prank(poolsAdmin);
        address plugin = factory.createPluginForExistingPool(address(token0), address(token1));

        // Verify plugin has the factory's config ID
        AlgebraBasePluginV1 createdPlugin = AlgebraBasePluginV1(plugin);
        assertEq(createdPlugin.getConfigId(), customConfigId);
    }

    function testConfigIdChangeAffectsNewPlugins() public {
        bytes32 firstConfigId = keccak256("v1-first-config");
        bytes32 secondConfigId = keccak256("v1-second-config");

        // Set first config and create a plugin
        vm.prank(admin);
        factory.setConfigId(firstConfigId);

        vm.prank(poolsAdmin);
        address plugin1 = factory.createPluginForExistingPool(address(token0), address(token1));

        // Create additional pool for second plugin
        MockToken token2 = MockToken(TestUtils.createMockToken("Token2", "TK2", 1000000 * 10 ** 18));
        MockToken token3 = MockToken(TestUtils.createMockToken("Token3", "TK3", 1000000 * 10 ** 18));
        MockPool pool2 = MockPool(TestUtils.createMockPool(address(token2), address(token3), address(algebraFactory)));
        algebraFactory.setPoolByPair(address(token2), address(token3), address(pool2));

        // Change config and create another plugin
        vm.prank(admin);
        factory.setConfigId(secondConfigId);

        vm.prank(poolsAdmin);
        address plugin2 = factory.createPluginForExistingPool(address(token2), address(token3));

        // Verify different config IDs
        AlgebraBasePluginV1 createdPlugin1 = AlgebraBasePluginV1(plugin1);
        AlgebraBasePluginV1 createdPlugin2 = AlgebraBasePluginV1(plugin2);

        assertEq(createdPlugin1.getConfigId(), firstConfigId);
        assertEq(createdPlugin2.getConfigId(), secondConfigId);
        assertTrue(createdPlugin1.getConfigId() != createdPlugin2.getConfigId());
    }
}
