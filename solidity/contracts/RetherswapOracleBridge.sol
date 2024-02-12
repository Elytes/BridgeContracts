// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.17;

import '../interfaces/IXERC20.sol';

struct ChainInfos {
    address xGasToken;
    uint256 gasFees;
}

contract RetherswapOracleBridge {
  mapping(bytes32 => bool) public actions; // keep this at the top to be slot 0
  mapping(bytes32 => bool) public consumedActions;
  mapping(bytes32 => bool) public authorizedActions;
  mapping(uint256 => ChainInfos) public chainInfos;

  address public xToken;
  uint256 public peerChain;
  address public oracleAdmin;
  uint256 public actionCounter;

  event ActionCreated(
    bytes32 indexed id,
    uint256 destinationChain,
    uint256 indexed nonce,
    address receiver,
    uint256 amount,
    uint256 gas
  );

  event ActionConsumed(
    bytes32 indexed id,
    uint256 destinationChain,
    uint256 indexed nonce,
    address receiver,
    uint256 amount,
    uint256 gas
  );

  function init(uint256 _peer, address xerc20, address _admin) public returns (bool)
  {
    if (peerChain != 0 || xToken != address(0) || oracleAdmin != address(0)) {
      revert();
    }

    peerChain = _peer;
    xToken = xerc20;
    oracleAdmin = _admin;
    return true;
  }

  function setChainInfos(uint256 idChain, address xGasToken, uint256 gasFees) public onlyOracleAdmin returns (bool success) {
    chainInfos[idChain] = ChainInfos(xGasToken, gasFees);
    return true;
  }

  function getChainId() public virtual view returns (uint256 chainId) {
    this; // Silence state mutability warning without generating any additional byte code
    assembly {
      chainId := chainid()
    }
  }

  function getActionId(uint256 fromChain, uint256 destinationChain, uint256 nonce, address recipient, uint256 amount, uint256 gas) public pure returns (bytes32 actionId) {
    return keccak256(abi.encodePacked(fromChain, destinationChain, nonce, recipient, amount, gas));
  }

  function authorizeAction(bytes32 action) public onlyOracleAdmin returns (bool success)
  {
    require(!consumedActions[action], 'Action already Consumed');
    require(!authorizedActions[action], 'Action already relayed');

    authorizedActions[action] = true;
    return true;
  }

  function burn(address recipient, uint256 destinationChain, uint256 amount, uint256 gas) public returns (bytes32 actionId)
  {
    actionCounter++;
    bytes32 id = getActionId(getChainId(), destinationChain, actionCounter, recipient, amount, gas);
    IXERC20(xToken).burn(msg.sender, amount);
    ChainInfos storage _chainInfos = chainInfos[destinationChain];
    // Burning gas required at destination + gas fees that will be required to run this transaction on destination chain
    IXERC20(_chainInfos.xGasToken).burn(msg.sender, gas + _chainInfos.gasFees);
    actions[id] = true;
    emit ActionCreated(id, destinationChain, actionCounter, recipient, amount, gas);
    return id;
  }

  function mint(address recipient, uint256 nonce, uint256 amount, uint256 gas) public returns (bool success)
  {
    bytes32 action = getActionId(peerChain, getChainId(), nonce, recipient, amount, gas);
    require(authorizedActions[action], 'Not Authorized!');
    require(!consumedActions[action], 'Already Minted!');

    consumedActions[action] = true;
    IXERC20(xToken).mint(recipient, amount);
    IXERC20(chainInfos[getChainId()].xGasToken).mint(recipient, gas);

    emit ActionConsumed(action, getChainId(), nonce, recipient, amount, gas);
    return true;
  }

  modifier onlyOracleAdmin() {
    require(msg.sender == oracleAdmin);
    _;
  }
}
