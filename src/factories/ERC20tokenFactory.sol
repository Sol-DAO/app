// SPDX-License-Identifier: BSD

pragma solidity ^0.8.4;

/// @title ClonesWithImmutableArgs
/// @author wighawag, zefram.eth, Saw-mon & Natalie, wminshew
/// @notice Enables creating clone contracts with immutable args
/// @dev extended by will@0xsplits.xyz to add receive() without DELEGECALL & create2 support
/// (h/t WyseNynja https://github.com/wighawag/clones-with-immutable-args/issues/4)
library ClonesWithImmutableArgs {
    error CreateFail();

    uint256 private constant FREE_MEMORY_POINTER_SLOT = 0x40;
    uint256 private constant BOOTSTRAP_LENGTH = 0x6f;
    uint256 private constant RUNTIME_BASE = 0x65; // BOOTSTRAP_LENGTH - 10 bytes
    uint256 private constant ONE_WORD = 0x20;
    // = keccak256("ReceiveETH(uint256)")
    uint256 private constant RECEIVE_EVENT_SIG =
        0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff;

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return ptr The ptr to the clone's bytecode
    /// @return creationSize The size of the clone to be created
    function cloneCreationCode(address implementation, bytes memory data)
        internal
        pure
        returns (uint256 ptr, uint256 creationSize)
    {
        // unrealistic for memory ptr or data length to exceed 256 bits
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let extraLength := add(mload(data), 2) // +2 bytes for telling how much data there is appended to the call
            creationSize := add(extraLength, BOOTSTRAP_LENGTH)
            let runSize := sub(creationSize, 0x0a)

            // free memory pointer
            ptr := mload(FREE_MEMORY_POINTER_SLOT)

            // -------------------------------------------------------------------------------------------------------------
            // CREATION (10 bytes)
            // -------------------------------------------------------------------------------------------------------------

            // 61 runtime  | PUSH2 runtime (r)     | r                       | –
            // 3d          | RETURNDATASIZE        | 0 r                     | –
            // 81          | DUP2                  | r 0 r                   | –
            // 60 offset   | PUSH1 offset (o)      | o r 0 r                 | –
            // 3d          | RETURNDATASIZE        | 0 o r 0 r               | –
            // 39          | CODECOPY              | 0 r                     | [0, runSize): runtime code
            // f3          | RETURN                |                         | [0, runSize): runtime code

            // -------------------------------------------------------------------------------------------------------------
            // RUNTIME (101 bytes + extraLength)
            // -------------------------------------------------------------------------------------------------------------

            // --- if no calldata, emit event & return w/o `DELEGATECALL`
            //     0x000     36       calldatasize      cds                  | -
            //     0x001     602f     push1 0x2f        0x2f cds             | -
            // ,=< 0x003     57       jumpi                                  | -
            // |   0x004     34       callvalue         cv                   | -
            // |   0x005     3d       returndatasize    0 cv                 | -
            // |   0x006     52       mstore                                 | [0, 0x20) = cv
            // |   0x007     7f9e4a.. push32 0x9e4a..   id                   | [0, 0x20) = cv
            // |   0x028     6020     push1 0x20        0x20 id              | [0, 0x20) = cv
            // |   0x02a     3d       returndatasize    0 0x20 id            | [0, 0x20) = cv
            // |   0x02b     a1       log1                                   | [0, 0x20) = cv
            // |   0x02c     3d       returndatasize    0                    | [0, 0x20) = cv
            // |   0x02d     3d       returndatasize    0 0                  | [0, 0x20) = cv
            // |   0x02e     f3       return
            // `-> 0x02f     5b       jumpdest

            // --- copy calldata to memory ---
            // 36          | CALLDATASIZE          | cds                     | –
            // 3d          | RETURNDATASIZE        | 0 cds                   | –
            // 3d          | RETURNDATASIZE        | 0 0 cds                 | –
            // 37          | CALLDATACOPY          |                         | [0 - cds): calldata

            // --- keep some values in stack ---
            // 3d          | RETURNDATASIZE        | 0                       | [0 - cds): calldata
            // 3d          | RETURNDATASIZE        | 0 0                     | [0 - cds): calldata
            // 3d          | RETURNDATASIZE        | 0 0 0                   | [0 - cds): calldata
            // 3d          | RETURNDATASIZE        | 0 0 0 0                 | [0 - cds): calldata
            // 61 extra    | PUSH2 extra (e)       | e 0 0 0 0               | [0 - cds): calldata

            // --- copy extra data to memory ---
            // 80          | DUP1                  | e e 0 0 0 0             | [0 - cds): calldata
            // 60 rb       | PUSH1 rb              | rb e e 0 0 0 0          | [0 - cds): calldata
            // 36          | CALLDATASIZE          | cds rb e e 0 0 0 0      | [0 - cds): calldata
            // 39          | CODECOPY              | e 0 0 0 0               | [0 - cds): calldata, [cds - cds + e): extraData

            // --- delegate call to the implementation contract ---
            // 36          | CALLDATASIZE          | cds e 0 0 0 0           | [0 - cds): calldata, [cds - cds + e): extraData
            // 01          | ADD                   | cds+e 0 0 0 0           | [0 - cds): calldata, [cds - cds + e): extraData
            // 3d          | RETURNDATASIZE        | 0 cds+e 0 0 0 0         | [0 - cds): calldata, [cds - cds + e): extraData
            // 73 addr     | PUSH20 addr           | addr 0 cds+e 0 0 0 0    | [0 - cds): calldata, [cds - cds + e): extraData
            // 5a          | GAS                   | gas addr 0 cds+e 0 0 0 0| [0 - cds): calldata, [cds - cds + e): extraData
            // f4          | DELEGATECALL          | success 0 0             | [0 - cds): calldata, [cds - cds + e): extraData

            // --- copy return data to memory ---
            // 3d          | RETURNDATASIZE        | rds success 0 0         | [0 - cds): calldata, [cds - cds + e): extraData
            // 3d          | RETURNDATASIZE        | rds rds success 0 0     | [0 - cds): calldata, [cds - cds + e): extraData
            // 93          | SWAP4                 | 0 rds success 0 rds     | [0 - cds): calldata, [cds - cds + e): extraData
            // 80          | DUP1                  | 0 0 rds success 0 rds   | [0 - cds): calldata, [cds - cds + e): extraData
            // 3e          | RETURNDATACOPY        | success 0 rds           | [0 - rds): returndata, ... the rest might be dirty

            // 60 0x63     | PUSH1 0x63            | 0x63 success            | [0 - rds): returndata, ... the rest might be dirty
            // 57          | JUMPI                 |                         | [0 - rds): returndata, ... the rest might be dirty

            // --- revert ---
            // fd          | REVERT                |                         | [0 - rds): returndata, ... the rest might be dirty

            // --- return ---
            // 5b          | JUMPDEST              |                         | [0 - rds): returndata, ... the rest might be dirty
            // f3          | RETURN                |                         | [0 - rds): returndata, ... the rest might be dirty

            mstore(
                ptr,
                or(
                    hex"6100003d81600a3d39f336602f57343d527f", // 18 bytes
                    shl(0xe8, runSize)
                )
            )

            mstore(
                   add(ptr, 0x12), // 0x0 + 0x12
                RECEIVE_EVENT_SIG // 32 bytes
            )

            mstore(
                   add(ptr, 0x32), // 0x12 + 0x20
                or(
                    hex"60203da13d3df35b363d3d373d3d3d3d610000806000363936013d73", // 28 bytes
                    or(shl(0x68, extraLength), shl(0x50, RUNTIME_BASE))
                )
            )

            mstore(
                   add(ptr, 0x4e), // 0x32 + 0x1c
                shl(0x60, implementation) // 20 bytes
            )

            mstore(
                   add(ptr, 0x62), // 0x4e + 0x14
                hex"5af43d3d93803e606357fd5bf3" // 13 bytes
            )

            // -------------------------------------------------------------------------------------------------------------
            // APPENDED DATA (Accessible from extcodecopy)
            // (but also send as appended data to the delegatecall)
            // -------------------------------------------------------------------------------------------------------------

            let counter := mload(data)
            let copyPtr := add(ptr, BOOTSTRAP_LENGTH)
            let dataPtr := add(data, ONE_WORD)

            for {} true {} {
                if lt(counter, ONE_WORD) { break }

                mstore(copyPtr, mload(dataPtr))

                copyPtr := add(copyPtr, ONE_WORD)
                dataPtr := add(dataPtr, ONE_WORD)

                counter := sub(counter, ONE_WORD)
            }

            let mask := shl(mul(0x8, sub(ONE_WORD, counter)), not(0))

            mstore(copyPtr, and(mload(dataPtr), mask))
            copyPtr := add(copyPtr, counter)
            mstore(copyPtr, shl(0xf0, extraLength))

            // Update free memory pointer
            mstore(FREE_MEMORY_POINTER_SLOT, add(ptr, creationSize))
        }
    }

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function clone(address implementation, bytes memory data)
        internal
        returns (address payable instance)
    {
        (uint256 creationPtr, uint256 creationSize) =
            cloneCreationCode(implementation, data);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            instance := create(0, creationPtr, creationSize)
        }

        // if the create failed, the instance address won't be set
        if (instance == address(0)) {
            revert CreateFail();
        }
    }

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        bytes memory data
    )
        internal
        returns (address payable instance)
    {
        (uint256 creationPtr, uint256 creationSize) =
            cloneCreationCode(implementation, data);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            instance := create2(0, creationPtr, creationSize, salt)
        }

        // if the create failed, the instance address won't be set
        if (instance == address(0)) {
            revert CreateFail();
        }
    }

    /// @notice Predicts the address where a deterministic clone of implementation will be deployed
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return predicted The predicted address of the created clone
    /// @return exists Whether the clone already exists
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        bytes memory data
    )
        internal
        view
        returns (address predicted, bool exists)
    {
        (uint256 creationPtr, uint256 creationSize) =
            cloneCreationCode(implementation, data);

        bytes32 creationHash;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            creationHash := keccak256(creationPtr, creationSize)
        }

        predicted = computeAddress(salt, creationHash, address(this));
        exists = predicted.code.length > 0;
    }

    /// @dev Returns the address where a contract will be stored if deployed via CREATE2 from a contract located at `deployer`.
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    )
        internal
        pure
        returns (address)
    {
        bytes32 _data =
            keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(_data)));
    }
}
