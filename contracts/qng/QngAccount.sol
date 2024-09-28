// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../core/BaseAccount.sol";
import "../samples/callback/TokenCallbackHandler.sol";

/**
 * minimal account.
 *  this is sample minimal account.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract QngAccount is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable
{
    using ECDSA for bytes32;

    address public owner;
    address public meerchange;
    IEntryPoint private immutable _entryPoint;

    // meerchange error code start from 10000
    uint256 internal constant SIG_MEERCHANGE_FAILED = 10000;
    uint256 internal constant SIG_MEERCHANGE_NOT_MATCHED = 10001;

    event QngAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint, address _meerchange) {
        _entryPoint = anEntryPoint;
        meerchange = _meerchange;
        _disableInitializers();
    }
    function changeMeerChange(address _meerchange) external onlyOwner {
        meerchange = _meerchange;
    }
    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            msg.sender == owner || msg.sender == address(this),
            "only owner"
        );
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of QngAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit QngAccountInitialized(_entryPoint, owner);
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner,
            "account: not Owner or EntryPoint"
        );
    }

    /// implement template method of BaseAccount
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        // if call meerchange methods, check op valid or not
        // 1. check sig is valid. 2. check txid exist and check txid and owner
        // 0:16 execute method sig
        // 16:36 meerchange contract address
        // 36:100 zero padding
        // 100:132 zero padding
        // 132:140 export method sig
        // 140:172 param0 txid
        // 172:204 param1 idx
        // 204:236 param2 fee
        // 236:300 params3 length
        // 300:430 params3 sig
        if (address(bytes20(userOp.callData[16:36])) == meerchange) {
            bytes32 txid = bytes32(userOp.callData[132:140]); // txid
            uint32 idx = uint32(uint256(bytes32(userOp.callData[172:204]))); // idx
            uint64 fee = uint64(uint256(bytes32(userOp.callData[204:236]))); // fee
            bytes memory signature = userOp.callData[300:430]; // signature
            bytes32 messageHash = getMessageHash(txid, idx, fee);
            if (owner != messageHash.recover(signature)) {
                return SIG_MEERCHANGE_FAILED;
            }
            // check txid exist and check txid and signature is matched
            // TODO
            // if (!meerchange.checkTxid(txid, idx, fee, signature)) {
            //     return SIG_MEERCHANGE_NOT_MATCHED;
            // }
        }
        return 0;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }

    function getMessageHash(
        bytes32 txid,
        uint32 idx,
        uint64 fee
    ) public pure returns (bytes32) {
        // 计算标准的 eth_sign 消息哈希
        return prefixed(keccak256(abi.encodePacked(txid, idx, fee)));
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }
}
