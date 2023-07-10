// SPDX-License-Identifier: None
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @custom:security-contact @Bigbadbeard
contract EventTicketing is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _seatIdCounter;

    //setting up the event
    uint256 public maxTickets;
    string public eventLocation;
    uint256 public eventTime;
    string public eventName;
    uint256 public cost;

    //setting up the ticket scanner role
    bytes32 public constant TICKET_SCANNER_ROLE = keccak256("TICKET_SCANNER_ROLE");
    mapping(address => uint256) public ticketScannerAddresses;

    //setting up ticket struct and related info
    struct Ticket {
        uint256 seatNumber; // Seat number
        uint256 cost; // Cost to buy
        uint256 date; // Date for ticket, this will be stored as a timestamp
        bool hasBeenScanned; // Boolean variable indicating if the ticket has been used
        bool isValid; // Boolean variable for if ticket has passed event date
        address purchaser; // Wallet address of the purchaser (0=not sold yet)
    }

    // Create tickets for this event
    mapping(uint256 => Ticket) public tickets;

    //Emit an event every time a ticket is scanned
    event TicketScanned(uint256 ticketId, address scanner);

    //Emit an event every time a ticket is revoked
    event TicketRevoked(uint256 ticketId);

    // Emit an event every time a ticket is created
    event TicketCreated(uint256 ticketId, address creator);

    // Emit an event every time a ticket is purchased
    event TicketBought(uint256 ticketId, address buyer);


    // This contract sets up the event
    constructor(uint256 _maxTickets, string memory _eventLocation, string memory _eventName, uint256 _eventTime) ERC721("EventTicketing", "EVTK") {
        maxTickets = _maxTickets;
        eventLocation = _eventLocation;
        eventTime = _eventTime;
        eventName = _eventName;
        cost = 100;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "http://www.tobedetermined.com";
    }

    function safeMint(uint256 numTickets) public onlyOwner {
        require(numTickets <= maxTickets, "Max number of tickets already minted");
        for (uint256 i = 0; i < numTickets; i++) {
            uint256 seatId = _seatIdCounter.current();
            _seatIdCounter.increment();
            _safeMint(msg.sender, seatId);
        }
    }

    function seatTaken(uint256 _seat) public view returns (bool) {
        return tickets[_seat].purchaser != address(0);
    }

    function setupTicketScannerRoles(address ticketScanner) public onlyOwner {
        grantRole(TICKET_SCANNER_ROLE, ticketScanner);
    }

    function createTicket(uint256 _ticketId, uint256 _seatNumber, uint256 _cost, uint256 _date) public onlyOwner {

        // Check that the seat number is not already in use
        require(!seatTaken(_seatNumber), "Seat already created");
        // Check that the ticketId is not greater than the maxTickets
        require(_ticketId <= maxTickets, "Ticket ID is greater than maxTickets");
        // Check that the seat number is not greater than the maxTickets
        require(_seatNumber <= maxTickets, "Seat number is greater than maxTickets");
        // Check that enough minted tickets exist
        require(_ticketId <= _seatIdCounter.current(), "Not enough minted tickets");

        // Create a new Ticket struct in memory
        Ticket memory newTicket = Ticket({
            seatNumber: _seatNumber,
            cost: _cost,
            date: _date,
            hasBeenScanned: false,
            isValid: true,
            purchaser: address(0)
        });

        // Store the new ticket in the tickets mapping
        tickets[_ticketId] = newTicket;

        emit TicketCreated(_ticketId, msg.sender);

    }

    // Create a function to allow a user to Buy a ticket
    function buyTicket (uint256 _seatNumber ) public payable {
        // Check that the seat number is not already in use
        require(!seatTaken(_seatNumber), "Seat already taken");
        // Check that enough minted tickets exist
        require(_seatNumber <= _seatIdCounter.current(), "Not enough minted tickets");
        // Check that the ticket is valid
        require(tickets[_seatNumber].isValid == true, "Ticket is not valid");
        // Check that the user has paid enough
        require(msg.value >= tickets[_seatNumber].cost, "Not enough funds sent");

        // Update the ticket struct in memory
        tickets[_seatNumber].purchaser = msg.sender;

        // Transfer the ticket to the user
        _safeMint(msg.sender, _seatNumber);

        // Refund any overpayment
        if (msg.value > tickets[_seatNumber].cost) {
            payable(msg.sender).transfer(msg.value - tickets[_seatNumber].cost);
        }

        emit TicketBought(_seatNumber, msg.sender);
    }

    // Function to get the price of a ticket
    function ticketPrice(uint256 ticket) public view returns (uint256) {
        // Return the desired ticket price
        return tickets[ticket].cost;
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function scanTicket(uint256 ticketId) public onlyRole(TICKET_SCANNER_ROLE) {
        require(tickets[ticketId].date != 0, "Ticket doesn't exist!");
        require(tickets[ticketId].isValid != false, "Ticket must be valid!");
        tickets[ticketId].hasBeenScanned = true;
        emit TicketScanned(ticketId, msg.sender);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    //function to revoke ticket
    function revokeTicket(uint256 ticketId) public onlyOwner {
        require(tickets[ticketId].date != 0, "Ticket doesn't exist!");
        tickets[ticketId].isValid = false;
        emit TicketRevoked(ticketId);
    }

    function getNumTicketsMinted() public view returns (uint256) {
        return _seatIdCounter.current();
    }

    //function withdraw()
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    //isValid()
    function isValid(uint256 ticketId) public view returns(bool) {
        require(tickets[ticketId].isValid != false, "Ticket doesn't exist!");
        bool _isValid = tickets[ticketId].isValid;
        return _isValid;
    }  
}