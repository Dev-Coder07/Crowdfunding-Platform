// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26; // Updated to recommended compiler version

contract Project {
    address public owner;
    string public title;
    string public description;
    uint256 public goalAmount;
    uint256 public raisedAmount;
    uint256 public deadline;
    bool public isCompleted;
    bool public isGoalReached;

    // Removed: address[] public contributors;
    // This array was the primary gas sink due to `push` operations.
    // Individual contributions are still tracked efficiently via the mapping.

    mapping(address => uint256) public contributions;

    event ContributionMade(address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 amount);
    event RefundIssued(address indexed contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only project owner can call this function");
        _;
    }

    modifier projectActive() {
        require(block.timestamp < deadline && !isCompleted, "Project is no longer active");
        _;
    }

    modifier projectEnded() {
        require(block.timestamp >= deadline || isCompleted, "Project is still active");
        _;
    }

    constructor(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) {
        owner = msg.sender;
        title = _title;
        description = _description;
        goalAmount = _goalAmount;
        deadline = block.timestamp + (_durationInDays * 1 days);
        raisedAmount = 0;
        isCompleted = false;
        isGoalReached = false;
    }

    // Core Function 1: Contribute to the project
    function contribute() public payable projectActive {
        require(msg.value > 0, "Contribution must be greater than 0");

        // Removed: Logic to add to contributors array for gas efficiency

        contributions[msg.sender] += msg.value;
        raisedAmount += msg.value;

        // Only update isGoalReached if it hasn't been reached yet
        if (!isGoalReached && raisedAmount >= goalAmount) {
            isGoalReached = true;
        }

        emit ContributionMade(msg.sender, msg.value);
    }

    // Core Function 2: Withdraw funds (only if goal is reached)
    function withdrawFunds() public onlyOwner projectEnded {
        require(isGoalReached, "Goal not reached, cannot withdraw funds");
        require(address(this).balance > 0, "No funds to withdraw from contract balance"); // Check actual contract balance
        require(raisedAmount > 0, "No raised amount to withdraw"); // Ensure raisedAmount matches what's expected

        uint256 amountToWithdraw = address(this).balance; // Withdraw the full balance of the contract
        raisedAmount = 0; // Reset raisedAmount as funds are withdrawn
        isCompleted = true; // Mark as completed once funds are withdrawn

        // Use a low-level call for robust transfer, with a check for success
        (bool success, ) = payable(owner).call{value: amountToWithdraw}("");
        require(success, "Failed to withdraw funds");

        emit FundsWithdrawn(amountToWithdraw);
    }

    // Core Function 3: Get refund (only if goal is not reached after deadline)
    function getRefund() public projectEnded {
        require(!isGoalReached, "Goal was reached, no refunds available");
        require(contributions[msg.sender] > 0, "No contribution found");

        uint256 refundAmount = contributions[msg.sender];
        contributions[msg.sender] = 0; // Reset contribution for this address

        // Use a low-level call for robust transfer, with a check for success
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Failed to send refund");

        emit RefundIssued(msg.sender, refundAmount);
    }

    // Helper functions
    function getProjectDetails() public view returns (
        string memory,
        string memory,
        uint256,
        uint256,
        uint256,
        bool,
        bool
        // Removed: uint256 for contributors.length for gas efficiency
    ) {
        return (
            title,
            description,
            goalAmount,
            raisedAmount,
            deadline,
            isCompleted,
            isGoalReached
        );
    }

    // Removed: function getContributorCount() as 'contributors' array was removed.

    function getTimeRemaining() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    // Fallback function to accept ether if someone sends it directly
    receive() external payable {
        // You might want to add a require here if direct sends outside of contribute() are not allowed.
        // For a crowdfunding contract, accepting direct sends could be seen as a contribution.
        // However, for strict logic, it's better to force contributions through the `contribute` function.
        // For simplicity and allowing direct sends, we'll just let it receive for now.
        // If you want to strictly enforce `contribute()` use `require(false, "Direct Ether transfers not allowed. Use contribute().");`
    }
}
