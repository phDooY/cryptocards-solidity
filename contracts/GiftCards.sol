pragma solidity >0.5.6;
pragma experimental ABIEncoderV2;

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
    uint256 public activationGasCost = 800000 * 6 * 10 ** 9; // Gas * Gas Price (assuming 6 gwei gas price)
    uint256 public feeAmountPercent = 1;

    // --- Administration ---
    address payable public owner;
    address payable public maintainer;
    uint256 public gasStationBalance;

    // --- Proxies ---
    KyberNetworkProxy public kyberNetworkProxyContract;
    DaiToken public daiToken;

    // --- Contract constructor ---
    constructor(address payable _owner, address payable _maintainer, address _daiAddress, address _kyberNetworkProxyAddress) public {
        owner = _owner;
        maintainer = _maintainer;
        kyberNetworkProxyContract = KyberNetworkProxy(_kyberNetworkProxyAddress);
        daiToken = DaiToken(_daiAddress);
    }

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, 'Not the owner of the contract!');
        _;
    }

    modifier onlyMaintainer() {
        require(msg.sender == maintainer, 'Not the maintainer of the contract!');
        _;
    }

    // --- Helper functions ---
    function withdrawProfits() public onlyOwner {
        uint256 profits = address(this).balance - gasStationBalance;
        owner.transfer(profits);
    }

    function refillGasStation() public onlyOwner {
        maintainer.transfer(gasStationBalance);
        gasStationBalance = 0;
    }

    function setMaintainer(address payable newAddress) public onlyOwner {
        maintainer = newAddress;
    }

    function setActivationGasCost(uint256 newValue) public onlyOwner {
        activationGasCost = newValue;
    }

    function setFeeAmountPercent(uint256 newValue) public onlyOwner {
        feeAmountPercent = newValue;
    }

    function setDAIContract(address newAddress) public onlyOwner {
        daiToken = DaiToken(newAddress);
    }

    function setKyberContract(address newAddress) public onlyOwner {
        kyberNetworkProxyContract = KyberNetworkProxy(newAddress);
    }

    // --- Events ---
    event CardCreation(bytes32 linkHash, uint256 nominalAmount, address buyer);
    event CardActivation(bytes32 linkHash, address recipient);

    // --- Structs ---
    struct Rates {
        uint256 buyConversionRate;
        uint256 sellConversionRate;
    }

    struct Card {
        uint256 initialAmountWei;
        uint256 buyAmountWei;
        uint256 sellAmountWei;
        uint256 amountDAI;
        uint256 nominalAmount;
        Rates rates;
        address buyer;
        string recipientName;
        address recipientAddress;
        bytes32 securityCodeHash;
        uint8 cardStyle;
    }

    mapping(bytes32 => Card) public cards;

    function cardExists(bytes32 _linkHash) public view returns(bool) {
        if (cards[_linkHash].buyer == address(0)) {
            return false;
        }
        return true;
    }

    function cardIsActivated(bytes32 _linkHash) public view returns(bool) {
        if (cards[_linkHash].recipientAddress == address(0)) {
            return false;
        }
        return true;
    }

    function createCard(bytes32 _linkHash,
                        string memory _recipientName,
                        bytes32 _securityCodeHash,
                        uint256 _nominalAmount,
                        uint8 _cardStyle
                        ) public payable returns(bool) {

        require(!cardExists(_linkHash), "The card already exists");

        uint256 actualValue = msg.value * (100 - feeAmountPercent) / 100 - activationGasCost;
        gasStationBalance += activationGasCost;

        // Call function that swaps Ethereum to DAI
        (cards[_linkHash].amountDAI, cards[_linkHash].rates.buyConversionRate) = _swapEtherToDai(actualValue);

        cards[_linkHash].nominalAmount = _nominalAmount;
        cards[_linkHash].buyAmountWei = actualValue;
        cards[_linkHash].initialAmountWei = msg.value;
        cards[_linkHash].buyer = msg.sender;
        cards[_linkHash].securityCodeHash = _securityCodeHash;
        cards[_linkHash].recipientName = _recipientName;
        cards[_linkHash].cardStyle = _cardStyle;

        emit CardCreation(_linkHash, _nominalAmount, msg.sender);

        return true;
    }

    function activateCard(bytes32 _linkHash, string memory _securityCode, address payable _recipientAddress) public onlyMaintainer returns(bool) {
        require(cardExists(_linkHash), "This card does not exist");
        require(!cardIsActivated(_linkHash), "This card has already been activated");

        require(keccak256(abi.encodePacked(_securityCode)) == cards[_linkHash].securityCodeHash, "Security code is invalid");

        (cards[_linkHash].sellAmountWei, cards[_linkHash].rates.sellConversionRate) = _swapDaiToEther(cards[_linkHash].amountDAI, _recipientAddress);

        cards[_linkHash].recipientAddress = _recipientAddress;

        emit CardActivation(_linkHash, _recipientAddress);

        return true;
    }

    function returnToBuyer(bytes32 _linkHash) public returns (bool) {
        require(cardExists(_linkHash), "This card does not exist");
        require(!cardIsActivated(_linkHash), "This card has already been activated");
        require(cards[_linkHash].buyer == msg.sender, "This account is not the buyer");

        (cards[_linkHash].sellAmountWei, cards[_linkHash].rates.sellConversionRate) = _swapDaiToEther(cards[_linkHash].amountDAI, msg.sender);

        cards[_linkHash].recipientAddress = msg.sender;

        return true;
    }

    // --- 3rd party integrations ---
    // Wrapper
    function getExpectedRate(address _base, address _target, uint value) public view returns(uint) {
        uint minRate;
        (, minRate) = kyberNetworkProxyContract.getExpectedRate(_base, _target, value);
        return minRate;
    }

    //@dev assumed to be receiving ether wei
    function _swapEtherToDai(uint value) internal returns(uint amountDAI, uint conversionRate) {
        uint minRate = getExpectedRate(ETH_TOKEN_ADDRESS, address(daiToken), value);

        //will send back tokens to this contract's address
        uint destAmount = kyberNetworkProxyContract.swapEtherToToken.value(value)(daiToken, minRate);

        // Send received tokens to the contract
        require(daiToken.transfer(address(this), destAmount), "DAI token transfer failed");
        return (destAmount, minRate);
    }

    // @param tokenQty token wei amount
    // @param destAddress address to send swapped ETH to
    function _swapDaiToEther(uint tokenQty, address payable destAddress) internal returns(uint amountWei, uint conversionRate) {
        uint minRate = getExpectedRate(address(daiToken), ETH_TOKEN_ADDRESS, tokenQty);

        // Mitigate ERC20 Approve front-running attack, by initially setting
        // allowance to 0
        require(daiToken.approve(address(kyberNetworkProxyContract), 0), "Pre approve of DAI token failed");

        // Approve tokens so network can take them during the swap
        require(daiToken.balanceOf(address(this)) >= tokenQty, "Trying to send too much of DAI");
        daiToken.approve(address(kyberNetworkProxyContract), tokenQty);
        uint destAmount = kyberNetworkProxyContract.swapTokenToEther(daiToken, tokenQty, minRate);

        // Send received ethers to destination address
        require(destAddress.send(destAmount), "ETH transfer failed");
        return(destAmount, minRate);
    }

    function() external payable  {
    }

}
