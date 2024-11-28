// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {console} from "forge-std/console.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EntryPoint} from "../contracts/core/EntryPoint.sol";
import {IEntryPoint} from "../contracts/interfaces/IEntryPoint.sol";
import {UserOperation} from "../contracts/interfaces/UserOperation.sol";

import {BaseAccount} from "../contracts/core/BaseAccount.sol";
import {QngAccount} from "../contracts/qng/QngAccount.sol";
import {QngAccountFactory} from "../contracts/qng/QngAccountFactory.sol";

contract QngAccountTest is Test {
    using stdStorage for StdStorage;
    using ECDSA for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    address payable public constant BENEFICIARY =
        payable(address(0xbe9ef1c1a2ee));
    bytes32 internal constant _MESSAGE_TYPEHASH =
        keccak256("QngAccountMessage(bytes message)");
    address public eoaAddress;
    QngAccount public account;
    EntryPoint public entryPoint;
    LightSwitch public lightSwitch;
    MeerChange public meerchange;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Initialized(uint64 version);

    function setUp() public {
        eoaAddress = vm.addr(EOA_PRIVATE_KEY);
        entryPoint = new EntryPoint();
        meerchange = new MeerChange();
        QngAccountFactory factory = new QngAccountFactory(
            entryPoint,
            address(meerchange)
        );
        account = factory.createAccount(eoaAddress, 1);
        vm.deal(address(account), 1 << 128);
        lightSwitch = new LightSwitch();
    }

    function testExecuteCanBeCalledByOwner() public {
        vm.prank(eoaAddress);
        account.execute(
            address(lightSwitch),
            0,
            abi.encodeCall(LightSwitch.turnOn, ())
        );
        assertTrue(lightSwitch.on());
    }

    function testExecuteWithValueCanBeCalledByOwner() public {
        vm.prank(eoaAddress);
        account.execute(
            address(lightSwitch),
            1 ether,
            abi.encodeCall(LightSwitch.turnOn, ())
        );
        assertTrue(lightSwitch.on());
        assertEq(address(lightSwitch).balance, 1 ether);
    }
    function testExecuteBatchCalledByOwner() public {
        vm.prank(eoaAddress);
        address[] memory dest = new address[](1);
        dest[0] = address(lightSwitch);
        bytes[] memory func = new bytes[](1);
        func[0] = abi.encodeCall(LightSwitch.turnOn, ());
        account.executeBatch(dest, func);
        assertTrue(lightSwitch.on());
    }

    function testInitialize() public {
        QngAccountFactory factory = new QngAccountFactory(
            entryPoint,
            address(meerchange)
        );

        emit Initialized(0);
        account = factory.createAccount(eoaAddress, 1);
    }

    function testCallMeerChange() public {
        bytes32 txid = bytes32(
            uint256(
                0xd47e847a8ac828abc27109b3f94a053c4dba53ccc6eb37cb7872435e0ee8936a
            )
        );
        uint32 idx = 0;
        uint64 fee = 10000;
        string
            memory sig = "3097947d270698a7f7d6bd5b9f4b725af77c9c866219893f75b63f2207370d5279249ec5cccc4973c343f299d086412c9443bb4f30e283a628f7043c6c0b14be00";
        account.execute(
            address(meerchange),
            0,
            abi.encodeCall(MeerChange.export, (txid, idx, fee, sig))
        );
        assertEq(meerchange.getExportCount(), 1);
    }

    function testEntryPointGetter() public {
        assertEq(address(account.entryPoint()), address(entryPoint));
    }
    function _getUnsignedOp(
        bytes memory callData
    ) internal view returns (UserOperation memory) {
        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit128 = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas128 = 1 << 8;
        return
            UserOperation({
                sender: address(account),
                nonce: 0,
                initCode: "",
                callData: callData,
                callGasLimit: (uint256(verificationGasLimit) << 128) |
                    callGasLimit128,
                verificationGasLimit: 1 << 24,
                preVerificationGas: 1 << 24,
                maxFeePerGas: (uint256(maxPriorityFeePerGas) << 128) |
                    maxFeePerGas128,
                maxPriorityFeePerGas: (uint256(maxPriorityFeePerGas) << 128) |
                    maxFeePerGas128,
                paymasterAndData: "",
                signature: ""
            });
    }

    function _getSignedOp(
        bytes memory callData,
        uint256 privateKey
    ) internal view returns (UserOperation memory) {
        UserOperation memory op = _getUnsignedOp(callData);
        op.signature = abi.encodePacked(
            _sign(
                privateKey,
                entryPoint.getUserOpHash(op).toEthSignedMessageHash()
            )
        );
        return op;
    }

    function _sign(
        uint256 privateKey,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Purposefully redefined here to surface any necessary updates to client-side message preparation for
    /// signing, in case `account.getMessageHash()` is updated.
    function _getMessageHash(
        bytes memory message
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(_MESSAGE_TYPEHASH, keccak256(message))
        );
        return keccak256(abi.encodePacked("\x19\x01", structHash));
    }
}

contract LightSwitch {
    bool public on;

    function turnOn() external payable {
        on = true;
    }
}

contract Reverter {
    function doRevert() external pure {
        revert("did revert");
    }
}

contract MeerChange {
    // Convert to UTXO precision
    uint256 public constant TO_UTXO_PRECISION = 1e10;
    // The count of call export
    uint64 private exportCount;
    // The count of call import
    uint64 private importCount;

    // events
    event Export(bytes32 txid, uint32 idx, uint64 fee, string sig);

    event Import();

    // Export amount from UTXO by EIP-4337
    function export(
        bytes32 txid,
        uint32 idx,
        uint64 fee,
        string calldata sig
    ) public {
        exportCount++;
        emit Export(txid, idx, fee, sig);
    }

    // Get the count of export
    function getExportCount() public view returns (uint64) {
        return exportCount;
    }

    // Import to UTXO account system
    function importToUtxo() external payable {
        uint256 up = msg.value / TO_UTXO_PRECISION;
        require(up > 0, "To UTXO amount must not be empty");
        importCount++;
        emit Import();
    }

    // Get the count of import
    function getImportCount() public view returns (uint64) {
        return importCount;
    }

    // Get the total of import amount
    function getImportTotal() external view returns (uint256) {
        return address(this).balance;
    }
}
