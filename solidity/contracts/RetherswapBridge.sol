// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {IXERC20} from '../interfaces/IXERC20.sol';
import {IXERC20Lockbox} from '../interfaces/IXERC20Lockbox.sol';
import {WRTH2} from './WRTH2.sol';
import {RetherswapOracleBridge} from './RetherswapOracleBridge.sol';


contract RetherswapBridge {
    address public xercAddress = 0x372c464C2cDF3A8cb39f243312465dC9e7C9b307;
    address public lockboxAddress = 0x674f374A804E99FDb1c1e00988A3Ccbe34389578;
    address public oracleBridgeAddress = 0x8D9b7634433298aB8BbF47b1a96789787Aa932F9;
    address payable public wrappedTokenAddress = payable(0x0000000000079c645A9bDE0Bd8Af1775FAF5598A);

    function bridge(uint256 destinationChain, uint256 amount, uint256 gas) public {
        WRTH2(wrappedTokenAddress).transferFrom(msg.sender, address(this), amount);
        IXERC20Lockbox(lockboxAddress).deposit(amount);
        RetherswapOracleBridge(oracleBridgeAddress).burn(msg.sender, destinationChain, amount, gas);
    }
}