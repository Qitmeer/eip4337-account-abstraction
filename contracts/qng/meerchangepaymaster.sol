// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable reason-string */

import "../core/BasePaymaster.sol";

contract MeerChangePaymaster is BasePaymaster {
    using UserOperationLib for UserOperation;

    // meerchange contract address
    address public meerchange;

    event Received(address sender, uint amount);

    constructor(
        IEntryPoint _entryPoint,
        address _meerchange
    ) BasePaymaster(_entryPoint) {
        meerchange = _meerchange;
    }
    /** this account may be used to receive ETH from bundler */
    receive() external payable {
        deposit();
        emit Received(msg.sender, msg.value);
    }

    // the meerchange has fee refunds
    // validate the request:
    // validatePaymasterUserOp
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        require(
            address(bytes20(userOp.callData[16:36])) == meerchange,
            "This paymentmaster is only designed for MeerChange"
        );
        require(
            entryPoint.balanceOf(address(this)) >= maxCost,
            "balance too low"
        );
        return (abi.encode(userOp, userOpHash, maxCost), 0);
    }

    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        (mode, context, actualGasCost);
    }
}
