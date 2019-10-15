pragma solidity >0.5.6;
// pragma experimental ABIEncoderV2;

contract GiftCards {

    // --- Administration ---
    address payable public owner;
    address public DAI;
    mapping(address => bool) isMaintainer;
    uint256 private _gasStationBalance;
    uint256 public activationGasPrice = 100000;
    uint8 public trials = 5;

    constructor(address payable _owner, address _DAI) public {
        owner = _owner;
        DAI = _DAI;
        // TODO initialize token from DAI address
        // DAI = DAI(_DAI);
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

    function setDAIContract(address newAddress) public onlyOwner {
        DAI = newAddress;
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

        // TODO call function that swaps Ethereum to DAI

        // uint256 result = DAI.swap(actualValue);
        // cards[_linkHash].amountDAI = result;
        // cards[_linkHash].conversionRate = DAI.getConversionRate();

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

}
