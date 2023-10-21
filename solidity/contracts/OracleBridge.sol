// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.17;

import "../interfaces/IXERC20.sol";

contract OracleBridgeTest {
  mapping(bytes32 => bool) public actions; // keep this at the top to be slot 0
  mapping(bytes32 => bool) public consumedActions;
  mapping(bytes32 => bool) public authorizedActions;

  address public xToken;
  uint256 public peerChain;
  address public oracleAdmin;
  uint256 public actionCounter;
  uint256 public gasCost = 0.05 ether;

  event ActionCreated(
    bytes32 indexed id,
    uint256 indexed nonce,
    address receiver,
    uint256 amount
  );

  event ActionConsumed(
    bytes32 indexed id,
    uint256 indexed nonce,
    address receiver,
    uint256 amount
  );

  event ActionRequested(
    bytes32 indexed id
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

  function getChainId() public virtual view returns (uint256 chainId) {
    this; // Silence state mutability warning without generating any additional byte code
    assembly {
      chainId := chainid()
    }
  }

  function getActionId(uint256 chainId, uint256 _nonce, address _recipient, uint256 _amount) public pure returns (bytes32 actionId) {
    return keccak256(abi.encodePacked(chainId, _nonce, _recipient, _amount));
  }

  function setGas(uint256 _gasCost) public onlyOracleAdmin
  {
    gasCost = _gasCost;
  }

  function authorizeAction(bytes32 action) public onlyOracleAdmin returns (bool success)
  {
    require(!consumedActions[action], "Action already Consumed");
    require(!authorizedActions[action], "Action already relayed");

    authorizedActions[action] = true;
    return true;
  }

  function requestAuthorization(bytes32 action) public payable returns (bool success)
  {
    require(msg.value >= gasCost, "Not enough GAS");
    require(!consumedActions[action], "Action already Consumed");
    require(!authorizedActions[action], "Action already relayed");

    payable(oracleAdmin).transfer(msg.value);

    emit ActionRequested(action);
    return true;
  }

  function burn(address _recipient, uint256 _amount) public returns (bytes32 actionId)
  {
    actionCounter++;
    bytes32 id = getActionId(getChainId(), actionCounter, _recipient, _amount);
    IXERC20(xToken).burn(msg.sender, _amount);
    actions[id] = true;
    emit ActionCreated(id, actionCounter, _recipient, _amount);
    return id;
  }

  function mint(address _recipient, uint256 nonce, uint256 amount) public returns (bool success)
  {
    bytes32 action = getActionId(peerChain, nonce, _recipient, amount);
    require(authorizedActions[action], "Not Authorized!");
    require(!consumedActions[action], "Already Minted!");

    consumedActions[action] = true;
    IXERC20(xToken).mint(_recipient, amount);

    emit ActionConsumed(action, nonce, _recipient, amount);
    return true;
  }

  modifier onlyOracleAdmin() {
    require(msg.sender == oracleAdmin);
    _;
  }
}
