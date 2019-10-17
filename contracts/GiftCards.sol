pragma solidity >0.5.6;
// pragma experimental ABIEncoderV2;

// import "./IERC20.sol";
// import "./KyberNetworkProxy.sol";

interface DaiToken {
    function transfer(address dst, uint wad) external returns (bool);
    function balanceOf(address guy) external view returns (uint);
}

interface KyberNetworkProxy {
    function getExpectedRate(address tokenAddress, DaiToken daiToken, uint amount) external view returns(uint expectedRate, uint slippageRate);
    function swapEtherToToken(DaiToken token, uint minConversionRate) external payable returns(uint);
}

contract GiftCards {
    // --- Administration ---
    address payable public owner;
    address public daiAddress;
    mapping(address => bool) isMaintainer;
    uint256 private _gasStationBalance;
    uint256 public activationGasPrice = 100000;
    uint8 public trials = 5;

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

    // --- Cards ---
    // TODO available time to activateCard

    // enum CardStatus { NULL, CREATED, ACTIVATED, REVERTED, RETURNED }

    struct Card {
        uint256 amountWei;
        uint256 amountDAI;
        uint256 nominalAmount; // needed?
        uint256 conversionRate; // needed?
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
        // (cards[_linkHash].amountDAI, cards[_linkHash].conversionRate) = _swapEtherToDai.value(actualValue)();
        (cards[_linkHash].amountDAI, cards[_linkHash].conversionRate) = _swapEtherToDai(actualValue);

        cards[_linkHash].amountWei = msg.value;
        cards[_linkHash].buyer = msg.sender;
        cards[_linkHash].linkHash = _linkHash;
        cards[_linkHash].securityCodeHash = _securityCodeHash;
        cards[_linkHash].trialsRemaining = trials;

        return true;
    }

    // TODO try to estimate and fix the gas cost of calling this function
    // cost should be a global variable
    function activateCard() public returns(bool) {
        return true;
    }

    function returnToBuyer(string memory linkHash) public returns (bool) {
        require(cards[linkHash].buyer == msg.sender, "You may not ??");
        return true;
    }

    // --- 3rd party integrations ---

    //@dev assumed to be receiving ether wei
    function _swapEtherToDai(uint value) internal returns(uint amountDAI, uint conversionRate) {
        uint minRate;
        (, minRate) = kyberNetworkProxyContract.getExpectedRate(address(0), daiToken, value);
        //will send back tokens to this contract's address
        uint destAmount = kyberNetworkProxyContract.swapEtherToToken.value(value)(daiToken, minRate);
        // Send received tokens to the contract
        require(daiToken.transfer(address(this), destAmount));
        return (destAmount, minRate);
    }

}
