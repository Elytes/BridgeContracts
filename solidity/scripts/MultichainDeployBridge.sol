// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {console} from 'forge-std/console.sol';
import {Test} from 'forge-std/Test.sol';
import {OracleBridgeTest} from '../contracts/OracleBridge.sol';
import {Script} from 'forge-std/Script.sol';
import {ScriptingLibrary} from './ScriptingLibrary/ScriptingLibrary.sol';
import {XERC20} from '../contracts/XERC20.sol';

contract MultichainDeployBridge is Script, ScriptingLibrary {
  uint256 public deployer = vm.envUint('DEPLOYER_PRIVATE_KEY');
  address constant CREATE2 = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
  string[] public chains = ['MAINNET_RPC', 'POLYGON_RPC'];

  function run() public {
    //TODO: Change salt from this test to prod before release
    bytes32 _salt = 0x67438ba50494a75101a15b8b0a7879c30aa89ce8ea19a512ecb48a53c828d4b1;
    address[] memory factories = new address[](chains.length);
    address[] memory token = new address[](chains.length);
    token[0] = 0xa74aDb26664612cD385ac8fAbcEAceB43c905fE3;
    token[1] = 0xa74aDb26664612cD385ac8fAbcEAceB43c905fE3;
    uint256[] memory peers = new uint256[](chains.length);
    peers[0] = 80001;
    peers[1] = 622277;
    address _deployedBridge = getAddress(type(OracleBridgeTest).creationCode, _salt, CREATE2);

    for (uint256 i; i < chains.length; i++) {
      vm.createSelectFork(vm.rpcUrl(vm.envString(chains[i])));
      vm.startBroadcast(deployer);

      if (keccak256(_deployedBridge.code) != keccak256(type(OracleBridgeTest).runtimeCode)) {
        new OracleBridgeTest{salt: _salt}();
      }

      OracleBridgeTest(_deployedBridge).init(peers[i], token[i], vm.addr(deployer));
      XERC20(token[i]).setLimits(_deployedBridge, 1000e18, 1000e18);

      vm.stopBroadcast();
      console.log(chains[i], 'Bridge deployed to:', address(_deployedBridge));
      factories[i] = _deployedBridge;
    }
  }
}
