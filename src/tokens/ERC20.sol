// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Clone} from "../utils/Clone.sol";

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 is Clone {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev approve() was called from address(0)
    error ApproveFromTheZeroAddress();

    /// @dev approve() is trying to send amount to address(0)
    error ApproveToTheZeroAddress();

    /// @dev transfer() was called from address(0)
    error TransferFromTheZeroAddress();

    /// @dev transfer() was trying to transfer to address(0)
    error TransferToTheZeroAddress();

    /// @dev Amount requested to be transfered was above the senders balance
    error TransferAmountExceedsBalance();

    /// @dev Allowed allowance is equal to the max uint256 value
    error AllowedEqualToMax();

    /// @dev Deadline param is below current block timestamp
    error DeadlineBelowBlockTimestamp();

    /// @dev The recoveredAddress is either not the owner or address(0)
    error InvalidSignerRecoveredAddress();

    /// @dev Trying to mint to address(0)
    error MintToTheZeroAddress();

    /// @dev Calling burn from address(0)
    error BurnFromTheZeroAddress();

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0)));
    }

    function symbol() external pure returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0x20)));
    }

    function decimals() external pure returns (uint8) {
        return _getArgUint8(0x40);
    }

    function chainId() external pure returns (uint8) {
        return _getArgUint256(0x60);
    }

    error ExpiredSignature();

    error InvalidSigner();

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    bool private _initialized;

    bytes32 private INITIAL_DOMAIN_SEPARATOR;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => uint256) public nonces; 


    modifier initializer() {
        if(_initialized){
            revert AlreadyInitialized();
        }
        _initialized = true;
        _;
    }

    function initialize() external initializer {
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool)
    {
        // require(owner != address(0), "ERC20: approve from the zero address");
        if (msg.sender == address(0)) revert ApproveFromTheZeroAddress();
        // require(spender != address(0), "ERC20: approve to the zero address");
        if (spender == address(0)) revert ApproveToTheZeroAddress();

        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        returns (bool)
    {
        // require(from != address(0), "ERC20: transfer from the zero address");
        if (msg.sender == address(0)) revert TransferFromTheZeroAddress();
        // require(to != address(0), "ERC20: transfer to the zero address");
        if (to == address(0)) revert TransferToTheZeroAddress();

        balanceOf[msg.sender] -= amount;

        // require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        if (balanceOf[msg.sender] < amount)
            revert TransferAmountExceedsBalance();

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed >= type(uint256).max) revert AllowedEqualToMax();

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (deadline < block.timestamp) revert DeadlineBelowBlockTimestamp();

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            allowance[recoveredAddress][spender] = value;
            if (recoveredAddress == address(0) || recoveredAddress != owner) {
                revert InvalidSignerRecoveredAddress();
            }
        }
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(
                        bytes(string(abi.encodePacked(_getArgUint256(0))))
                    ),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        // require(account != address(0), "ERC20: mint to the zero address");
        if (to == address(0)) revert MintToTheZeroAddress();

        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        // require(account != address(0), "ERC20: burn from the zero address");
        if (from == address(0)) revert BurnFromTheZeroAddress();

        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        // require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

     /*//////////////////////////////////////////////////////////////
                        EIP-21612 Logic
    //////////////////////////////////////////////////////////////*/

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r,bytes32 s) public virtual {
        if(deadline < block.timestamp){
            revert ExpiredSignature();
        }

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0) || recoveredAddress != owner){
                revert InvalidSigner();
            }

            allowance[recoveredAddress][spender] = value;
        }
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name())),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
    
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == chainId() ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }
    
}
