pragma solidity >0.5.6;
// TODO change from public mapping to getter
pragma experimental ABIEncoderV2;

// import "./IERC20.sol";
// import "./KyberNetworkProxy.sol";

interface DaiToken {
    function transfer(address dst, uint wad) external returns (bool);
    function balanceOf(address guy) external view returns (uint);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

interface KyberNetworkProxy {
    function getExpectedRate(address tokenAddress, address daiToken, uint amount) external view returns(uint expectedRate, uint slippageRate);
    function swapEtherToToken(DaiToken token, uint minConversionRate) external payable returns(uint);
    function swapTokenToEther(DaiToken token, uint srcAmount, uint minConversionRate) external returns(uint);
}

contract GiftCards {
    // --- Constants ---
    address constant ETH_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public activationGasPrice = 100000;
    uint8 public trials = 5;
    // --- Administration ---
    address payable public owner;
    address public daiAddress;
    mapping(address => bool) isMaintainer;
    uint256 private _gasStationBalance;

    KyberNetworkProxy public kyberNetworkProxyContract;
    DaiToken public daiToken;

    constructor(address payable _owner, address _daiAddress, address _kyberNetworkProxyAddress) public {
        owner = _owner;
        kyberNetworkProxyContract = KyberNetworkProxy(_kyberNetworkProxyAddress);
        daiToken = DaiToken(_daiAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function addMaintainer(address _address) public onlyOwner {
        isMaintainer[_address] = true;
    }

    function removeMaintainer(address _address) public onlyOwner {
        isMaintainer[_address] = false;
    }

    function withdrawProfits() public onlyOwner {
        uint256 profits = address(this).balance - _gasStationBalance;
        owner.transfer(profits);
    }

    function setNumberOfTrials(uint8 newValue) public onlyOwner {
        trials = newValue;
    }

    function setActivationGasPrice(uint256 newValue) public onlyOwner {
        activationGasPrice = newValue;
    }

    // TODO fix this
    function setDAIContract(address newAddress) public onlyOwner {
        daiAddress = newAddress;
        // TODO initialize token from address
    }

    // --- Events ---
    // TODO
    event CardCreation(string linkHash);

    // --- Cards ---
    // TODO available time to activateCard

    // enum CardStatus { NULL, CREATED, ACTIVATED, REVERTED, RETURNED }

    // TODO think how to split variables into structs
    struct Rates {
        uint256 buyConversionRate;
        uint256 sellConversionRate;
    }

    struct Card {
        uint256 initialAmountWei;
        uint256 buyAmountWei;
        uint256 sellAmountWei;
        uint256 amountDAI;
        uint256 nominalAmount; // needed?
        Rates rates;
        address buyer;
        string recipientName; // define size
        address recipientAddress; // needed?
        uint8 trialsRemaining;
        string linkHash; // define size
        string securityCodeHash; // define size
        // CardStatus status;
    }

    // TODO performance with a lot of cards?
    mapping(string => Card) public cards;

    function cardExists(string memory _linkHash) public view returns(bool) {
        // if (cards[_linkHash].status != CardStatus.CREATED) {
        if (cards[_linkHash].buyer == address(0)) {
            return false;
        }
        return true;
    }

    function cardIsActivated(string memory _linkHash) public view returns(bool) {
        if (cards[_linkHash].recipientAddress == address(0)) {
            return false;
        }
        return true;
    }

    function createCard(string memory _linkHash,
                        string memory _recipientName,
                        string memory _securityCodeHash)
                        payable
                        public returns(bool) {

        require(!cardExists(_linkHash), "The card already exists");
        // TODO find out requirements for msg.value vs nominalAmount
        // require(???)

        // TODO check gas cost
        uint256 actualValue = msg.value * 99 / 100 - activationGasPrice * trials;
        // uint256 actualValue = msg.value - msg.value / 100 - activationGasPrice * trials;

        // Call function that swaps Ethereum to DAI
        // (cards[_linkHash].amountDAI, cards[_linkHash].buyConversionRate) = _swapEtherToDai.value(actualValue)();
        (cards[_linkHash].amountDAI, cards[_linkHash].rates.buyConversionRate) = _swapEtherToDai(actualValue);

        cards[_linkHash].buyAmountWei = actualValue;
        cards[_linkHash].initialAmountWei = msg.value;
        cards[_linkHash].buyer = msg.sender;
        cards[_linkHash].linkHash = _linkHash;
        cards[_linkHash].securityCodeHash = _securityCodeHash;
        cards[_linkHash].trialsRemaining = trials;
        cards[_linkHash].recipientName = _recipientName;

        // TODO
        emit CardCreation(_linkHash);

        return true;
    }

    // TODO try to estimate and fix the gas cost of calling this function
    // cost should be a global variable
    function activateCard(string memory _linkHash, string memory _securityCodeHash, address payable _recipientAddress) public returns(bool) {
        require(cardExists(_linkHash), "This card does not exist");
        require(!cardIsActivated(_linkHash), "This card has already been activated");

        if (isMaintainer[msg.sender]) {
            require(cards[_linkHash].trialsRemaining != 0, "Out of trials");
            cards[_linkHash].trialsRemaining--;
        }

        require(keccak256(abi.encodePacked(_securityCodeHash)) == keccak256(abi.encodePacked(cards[_linkHash].securityCodeHash)), "Security code is invalid");

        (cards[_linkHash].sellAmountWei, cards[_linkHash].rates.sellConversionRate) = _swapDaiToEther(cards[_linkHash].amountDAI, _recipientAddress);

        // Send ether from contract to recipient
        // _recipientAddress.transfer(cards[_linkHash].sellAmountWei);

        cards[_linkHash].recipientAddress = _recipientAddress;

        return true;
    }

    function returnToBuyer(string memory linkHash) public returns (bool) {
        require(cards[linkHash].buyer == msg.sender, "You may not ??");
        return true;
    }

    // --- 3rd party integrations ---
    // Wrapper
    // function getExpectedRate(bool toDai, uint value) public view returns(uint) {
    //     uint minRate;
    //     if (toDai) {
    //         (, minRate) = kyberNetworkProxyContract.getExpectedRate(ETH_TOKEN_ADDRESS, address(daiToken), value);
    //     }
    //     else {
    //         (, minRate) = kyberNetworkProxyContract.getExpectedRate(address(daiToken), ETH_TOKEN_ADDRESS, value);
    //     }
    //     return minRate;
    // }

    //@dev assumed to be receiving ether wei
    function _swapEtherToDai(uint value) internal returns(uint amountDAI, uint conversionRate) {
        // uint minRate = getExpectedRate(true, value);

        uint minRate;
        (, minRate) = kyberNetworkProxyContract.getExpectedRate(ETH_TOKEN_ADDRESS, address(daiToken), value);
        //will send back tokens to this contract's address
        uint destAmount = kyberNetworkProxyContract.swapEtherToToken.value(value)(daiToken, minRate);
        // Send received tokens to the contract
        require(daiToken.transfer(address(this), destAmount));
        return (destAmount, minRate);
    }

    // @param tokenQty token wei amount
    // @param destAddress address to send swapped ETH to
    function _swapDaiToEther(uint tokenQty, address payable destAddress) internal returns(uint amountWei, uint conversionRate) {

        // uint minRate = getExpectedRate(false, tokenQty);

        uint minRate;
        (, minRate) = kyberNetworkProxyContract.getExpectedRate(address(daiToken), ETH_TOKEN_ADDRESS, tokenQty);

        // Mitigate ERC20 Approve front-running attack, by initially setting
        // allowance to 0
        require(daiToken.approve(address(kyberNetworkProxyContract), 0));

        // Approve tokens so network can take them during the swap
        require(daiToken.balanceOf(address(this)) >= tokenQty, "Trying to send too much of DAI");
        daiToken.approve(address(kyberNetworkProxyContract), tokenQty);
        uint destAmount = kyberNetworkProxyContract.swapTokenToEther(daiToken, tokenQty, minRate);

        // Send received ethers to destination address
        require(destAddress.send(destAmount));

        // destAddress.transfer(destAmount);
        return(destAmount, minRate);
    }

    function() payable external {
    }

}
