pragma solidity ^0.8.6;

// SPDX-License-Identifier: GPL

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/// @author DrGorilla.eth / Voyager Media Group
/// @title Memories Subscription: individual creators
/// @notice this is the generic NFT compatible subscription token.
/// @dev This contract is non-custodial. Accepted token is set by factory. totalySupply is, de facto, tthe current id minted,
/// prices are expressed in wei per seconds.

contract VoyrSubscriptions is IERC721, Ownable {

    uint256 public totalSupply;
    
    struct Plan {
        uint256 subscription_length;
        uint256 price;
    }

    Plan[] public plans; //each elt is a plan as in "Pay PRICE token for SUBSCRIPTION_LENGTH seconds"

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

    function newSub(uint256 number_of_periods, uint256 plan) external {
        require(number_of_periods != 0, "Sub: Invalid sub duration");
        if(_owned[msg.sender] != 0) renewSub(number_of_periods, plan);
        else {
            uint256 current_id = totalSupply;
            _owned[msg.sender] = current_id;
            _owners[current_id] = msg.sender;
            emit Transfer(address(this), msg.sender, current_id);
            totalSupply++;
            _processPayment(number_of_periods, plan);
        }
    }

    function renewSub(uint256 number_of_periods, uint256 plan) public {
        require(number_of_periods != 0, "Sub: Invalid sub duration");
        require(_owned[msg.sender] != 0, "Sub: No sub owned");
        _processPayment(number_of_periods, plan);
    }

    function _processPayment(uint256 number_of_periods, uint256 plan) internal {
        require(!paused, "Creator paused");
        uint256 price = plans[plan].price;
        uint256 subscription_length = plans[plan].subscription_length;
        uint256 to_pay = price  * number_of_periods;
        uint256 total_duration = subscription_length * number_of_periods;
        require(payment_token.allowance(msg.sender, address(this)) >= to_pay, "IERC20: insuf approval");
        
        expirations[msg.sender] = expirations[msg.sender] >= block.timestamp ?  expirations[msg.sender] + total_duration : block.timestamp + total_duration;
        
        payment_token.transferFrom(msg.sender, creator, to_pay);
    }

    function addNewPlan(uint256 price, uint256 duration) external onlyAdmin {
        Plan memory new_plan;
        new_plan.subscription_length = duration;
        new_plan.price = price;
        plans.push(new_plan);
    }

    function modifyPlan(uint256 price, uint256 duration, uint256 index) external onlyAdmin {
        plans[index].price = price;
        plans[index].subscription_length = duration;
    }

    function deletePlan(uint256 index) external onlyAdmin {
        require(index < plans.length, "Sub: invalid index");
        plans[index] = plans[plans.length-1];
        plans.pop();
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
        if(_owned[_adr] == 0) {
            _owned[_adr] = totalSupply;
            _owners[totalSupply] = _adr;
            emit Transfer(address(this), _adr, totalSupply);
            totalSupply++;
        }
        expirations[_adr] = expirations[_adr] >= block.timestamp ?  expirations[_adr] + length : block.timestamp + length;
    }

    function setPaymentToken(address _token) external onlyAdmin {
        payment_token = IERC20(_token);
        require(payment_token.totalSupply() != 0, "Set payment: Invalid ERC20");
    }

    /// @dev frontend integration: prefer accessing the mapping itself to compare with Date.now() (instead of last block timestamp)
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
