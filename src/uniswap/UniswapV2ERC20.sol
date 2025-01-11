pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2ERC20.sol";

contract UniswapV2ERC20 is IUniswapV2ERC20 {
    string private constant _name = "Uniswap V2";
    string private constant _symbol = "UNI-V2";
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balanceOf;
    mapping(address => mapping(address => uint256)) private _allowance;

    bytes32 private _DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) private _nonces;

    constructor() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function name() public pure override returns (string memory) {
        return _name;
    }

    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balanceOf[owner];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowance[owner][spender];
    }

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner];
    }

    function _mint(address to, uint256 value) internal {
        _totalSupply += value;
        _balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        _balanceOf[from] -= value;
        _totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) private {
        _allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        require(_balanceOf[msg.sender] >= value, "UniswapV2: INSUFFICIENT_BALANCE");
        _balanceOf[msg.sender] -= value;
        _balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        require(_balanceOf[from] >= value, "UniswapV2: INSUFFICIENT_BALANCE");
        require(_allowance[from][msg.sender] >= value, "UniswapV2: INSUFFICIENT_ALLOWANCE");
        _balanceOf[from] -= value;
        _balanceOf[to] += value;
        _allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {
        require(deadline >= block.timestamp, "UniswapV2: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "UniswapV2: INVALID_SIGNATURE");
        _approve(owner, spender, value);
    }
}
