
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EventTicketVerification {

    // Event organizer
    address public organizer;

    // Ticket status
    enum TicketStatus {
        Available,
        Active,
        Used,
        Cancelled
    }

    // Ticket details
    struct Ticket {
        uint256 ticketId;
        string eventName;
        uint256 originalPrice;
        address ticketOwner;
        TicketStatus status;
        bool exists;
    }

    // Ticket counter
    uint256 public ticketCounter;

    // Store tickets
    mapping(uint256 => Ticket) private tickets;

    // Resale information
    mapping(uint256 => uint256) public resalePrices;
    mapping(uint256 => bool) public listedForResale;

    // Prevent re-entrancy during payments
    bool private locked;

    // Events
    event TicketCreated(
        uint256 ticketId,
        string eventName,
        uint256 price
    );

    event TicketPurchased(
        uint256 ticketId,
        address buyer,
        uint256 price
    );

    event TicketTransferred(
        uint256 ticketId,
        address from,
        address to,
        uint256 resalePrice
    );

    event TicketUsed(uint256 ticketId);

    event TicketCancelled(uint256 ticketId);

    // Constructor
    constructor() {
        organizer = msg.sender;
    }

    // Restrict functions to organizer
    modifier onlyOrganizer() {
        require(
            msg.sender == organizer,
            "Only organizer can perform this action"
        );
        _;
    }

    // Payment protection
    modifier nonReentrant() {
        require(!locked, "Reentrant call detected");
        locked = true;
        _;
        locked = false;
    }

    // 1. Create a new ticket
    function createTicket(
        string memory _eventName,
        uint256 _price
    ) external onlyOrganizer returns (uint256) {

        require(bytes(_eventName).length > 0, "Event name required");
        require(_price > 0, "Price must be greater than zero");

        ticketCounter++;

        tickets[ticketCounter] = Ticket({
            ticketId: ticketCounter,
            eventName: _eventName,
            originalPrice: _price,
            ticketOwner: address(0),
            status: TicketStatus.Available,
            exists: true
        });

        emit TicketCreated(
            ticketCounter,
            _eventName,
            _price
        );

        return ticketCounter;
    }

    // 2. Purchase a ticket
    function buyTicket(
        uint256 _ticketId
    ) external payable nonReentrant {

        Ticket storage ticket = tickets[_ticketId];

        require(ticket.exists, "Ticket does not exist");
        require(
            ticket.status == TicketStatus.Available,
            "Ticket is not available"
        );
        require(
            msg.value == ticket.originalPrice,
            "Incorrect ticket price"
        );

        ticket.ticketOwner = msg.sender;
        ticket.status = TicketStatus.Active;

        // Transfer payment to organizer
        (bool success, ) = payable(organizer).call{
            value: msg.value
        }("");

        require(success, "Payment failed");

        emit TicketPurchased(
            _ticketId,
            msg.sender,
            msg.value
        );
    }

    // 3. List ticket for resale
    function listTicketForResale(
        uint256 _ticketId,
        uint256 _resalePrice
    ) external {
        Ticket storage ticket = tickets[_ticketId];

        require(ticket.exists, "Ticket does not exist");
        require(ticket.status == TicketStatus.Active, "Ticket is not active");
        require(ticket.ticketOwner == msg.sender, "Not ticket owner");

        require(_resalePrice > 0, "Invalid resale price");

        require(
            _resalePrice <= (ticket.originalPrice * 110) / 100,
            "Resale exceeds 10 percent limit"
        );

        require(!listedForResale[_ticketId], "Ticket already listed");

        resalePrices[_ticketId] = _resalePrice;
        listedForResale[_ticketId] = true;
    }

    // 4. Buy a resale ticket
    function buyResaleTicket(
        uint256 _ticketId
    ) external payable nonReentrant {
        Ticket storage ticket = tickets[_ticketId];

        require(ticket.exists, "Ticket does not exist");
        require(ticket.status == TicketStatus.Active, "Ticket not active");
        require(listedForResale[_ticketId], "Ticket not listed");
        require(msg.sender != ticket.ticketOwner, "Owner cannot buy own ticket");

        uint256 price = resalePrices[_ticketId];
        address previousOwner = ticket.ticketOwner;

        require(msg.value == price, "Incorrect resale payment");

        // Update ownership and remove listing
        ticket.ticketOwner = msg.sender;
        listedForResale[_ticketId] = false;
        resalePrices[_ticketId] = 0;

        // Send payment to previous owner
        (bool success, ) = payable(previousOwner).call{
            value: msg.value
        }("");

        require(success, "Resale payment failed");

        emit TicketTransferred(
            _ticketId,
            previousOwner,
            msg.sender,
            price
        );
    }

    // 4. Verify ticket authenticity
    function verifyTicket(
        uint256 _ticketId
    ) external view returns (bool) {

        Ticket storage ticket = tickets[_ticketId];

        return (
            ticket.exists &&
            ticket.status == TicketStatus.Active &&
            ticket.ticketOwner != address(0)
        );
    }

    // 5. Mark ticket as USED
    function useTicket(
        uint256 _ticketId
    ) external onlyOrganizer {

        Ticket storage ticket = tickets[_ticketId];

        require(ticket.exists, "Ticket does not exist");
        require(
            ticket.status == TicketStatus.Active,
            "Ticket is not valid or already used"
        );

        ticket.status = TicketStatus.Used;
        listedForResale[_ticketId] = false;
        resalePrices[_ticketId] = 0;

        emit TicketUsed(_ticketId);
    }

    // 6. Cancel ticket
    function cancelTicket(
        uint256 _ticketId
    ) external onlyOrganizer {

        Ticket storage ticket = tickets[_ticketId];

        require(ticket.exists, "Ticket does not exist");
        require(
            ticket.status == TicketStatus.Available ||
            ticket.status == TicketStatus.Active,
            "Ticket cannot be cancelled"
        );

        ticket.status = TicketStatus.Cancelled;
        listedForResale[_ticketId] = false;
        resalePrices[_ticketId] = 0;

        emit TicketCancelled(_ticketId);
    }

    // 7. Get ticket details
    function getTicketDetails(
        uint256 _ticketId
    )
        external
        view
        returns (
            uint256 ticketId,
            string memory eventName,
            uint256 originalPrice,
            address ticketOwner,
            TicketStatus status
        )
    {
        Ticket storage ticket = tickets[_ticketId];

        require(ticket.exists, "Ticket does not exist");

        return (
            ticket.ticketId,
            ticket.eventName,
            ticket.originalPrice,
            ticket.ticketOwner,
            ticket.status
        );
    }
}
