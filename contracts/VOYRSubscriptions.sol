pragma solidity ^0.8.6;

// SPDX-License-Identifier: GPL

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


/// @author DrGorilla.eth / Voyager Media Group
/// @title Memories Subscription: individual creators
/// @notice this is the generic NFT compatible subscription token.
/// @dev accepted token is set by factory. totalySupply is, de facto, tthe current id minted,
/// prices are expressed in wei per seconds. 

contract VoyrMemoriesSubscriptions is IERC721, Ownable {

    uint256 totalSupply;
    uint256 public current_price; //in wei per second

    bool paused;

    address creator;

    string private _symbol;

    IERC20 payment_token;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _owned;
    mapping(address => uint256) public expirations; //adr->timestamp of the end of current subscription

    modifier onlyAdmin {
        require(msg.sender == creator || msg.sender == owner(), "Sub: unauthorized");
        _;
    }

    constructor(address _creator, string memory _id, address token_adr) {
        _symbol = _id;
        creator = _creator;
        payment_token = IERC20(token_adr);
        totalSupply = 1; //0 reserved for invalid entry
    }

    function balanceOf(address _owner) public view virtual override returns (uint256) {
        require(_owner != address(0), "Sub: balance query for the zero address");
        if(_owned[_owner] != 0) return 1;
        return 0;
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address _owner = _owners[tokenId];
        require(_owner != address(0), "Sub: owner query for nonexistent token");
        return _owner;
    }

    function name() public view virtual returns (string memory) {
        return "VOYR SUB";
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /// @param length duration of subscription, in seconds
    function newSub(uint256 length) external {
        require(length != 0, "Sub: Invalid sub duration");
        if(_owned[msg.sender] != 0) renewSub(_owned[msg.sender]);
        else {
            uint256 current_id = totalSupply;
            _owned[msg.sender] = current_id;
            _owners[current_id] = msg.sender;
            emit Transfer(address(this), msg.sender, current_id);
            totalSupply++;
            _processPayment(length);
        }
    }

    function renewSub(uint256 length) public {
        require(length != 0, "Sub: Invalid sub duration");
        require(_owned[msg.sender] != 0, "Sub: No sub owned");
        _processPayment(length);
    }

    function _processPayment(uint256 length) internal {
        require(!paused, "Creator paused");
        uint256 to_pay = current_price  * length;
        require(payment_token.allowance(msg.sender, creator) >= to_pay, "IERC20: insuf approval");
        
        expirations[msg.sender] = expirations[msg.sender] >= block.timestamp ?  expirations[msg.sender] + length : block.timestamp + length;
        
        payment_token.transferFrom(msg.sender, creator, to_pay);
    }

    function setCurrentPrice(uint256 _price) external onlyAdmin {
        current_price = _price;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function resume() external onlyOwner {
        paused = false;
    }

    function burn(address _adr) external onlyOwner {
        require(_owned[_adr] != 0, "Sub burn: no token owned");
        uint256 id = _owned[_adr];
        delete _owned[_adr];
        _owners[id] = address(0);
        delete expirations[_adr];

        emit Transfer(_adr, address(0), id);
    }
    
    function sendSubscription(address _adr, uint256 length) external onlyOwner {
        if(_owned[msg.sender] == 0) {
            _owned[msg.sender] = totalSupply;
            _owners[totalSupply] = msg.sender;
            emit Transfer(address(this), msg.sender, totalSupply);
            totalSupply++;
        }
        expirations[_adr] = expirations[_adr] >= block.timestamp ?  expirations[_adr] + length : block.timestamp + length;
    }

    function setPaymentToken(address _token) external onlyAdmin {
        payment_token = IERC20(_token);
        require(payment_token.totalSupply() != 0, "Set payment: Invalid ERC20");
    }

    /// @dev frontend integration: prefer accessing the mapping itself to get date.now (instead of last block timestamp)
    function subscriptionActive() external view returns (bool) {
        return expirations[msg.sender] >= block.timestamp;
    }

    function getCreator() external view returns (address) {
        return creator;
    }


/// @dev no use case:

    function approve(address to, uint256 tokenId) public virtual override {}

    function getApproved(uint256 tokenId) public view virtual override returns (address) {return address(0);}

    function setApprovalForAll(address operator, bool approved) public virtual override {}

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {return false;}

    function transferFrom(address from,address to,uint256 tokenId) public virtual override {}

    function safeTransferFrom(address from,address to,uint256 tokenId) public virtual override {}

    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public virtual override {}

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {return false;}

}
