# Lending Protocol Contract

# Import statements
from vyper.interfaces import ERC20

# Define the LendingProtocol contract
contract LendingProtocol:
    # Struct to represent a loan
    struct Loan:
        borrower: address
        amount: uint256
        collateral: uint256
        interestRate: uint256
        duration: uint256
        status: uint256
        startTime: uint256
        endTime: uint256
        repaymentAmount: uint256

    # Mapping to store loans
    loans: public(map(uint256, Loan))

    # ERC20 token interface
    token: ERC20

    # Constructor function
    def __init__(token_address: address):
        self.token = ERC20(token_address)

    # Function to create a new loan
    @external
    def createLoan(amount: uint256, collateral: uint256, interestRate: uint256, duration: uint256):
        # Transfer collateral from borrower to contract
        self.token.transferFrom(msg.sender, self.address, collateral)

        # Create a new loan
        loan_id: uint256 = self._generateLoanID()
        self.loans[loan_id] = Loan({
            borrower: msg.sender,
            amount: amount,
            collateral: collateral,
            interestRate: interestRate,
            duration: duration,
            status: 1,  # Status 1 represents active loan
            startTime: block.timestamp,
            endTime: block.timestamp + duration * 1 days,  # Assume duration is in days
            repaymentAmount: amount + amount * interestRate / 100
        })

    # Internal function to generate a unique loan ID
    @internal
    def _generateLoanID() -> uint256:
        return block.timestamp  # Use timestamp as loan ID for simplicity

    # Function to get loan details by ID
    @external
    @view
    def getLoanDetails(loan_id: uint256) -> Loan:
        return self.loans[loan_id]

    # Function to repay a loan
    @external
    def repayLoan(loan_id: uint256):
        loan = self.loans[loan_id]
        require(loan.status == 1, "Loan is not active")
        require(block.timestamp < loan.endTime, "Loan repayment period has expired")

        # Transfer loan amount plus interest to contract
        self.token.transferFrom(msg.sender, self.address, loan.repaymentAmount)
        # Transfer collateral back to borrower
        self.token.transfer(loan.borrower, loan.collateral)
        # Update loan status to closed
        self.loans[loan_id].status = 0

    # Function to liquidate undercollateralized loans
    @external
    def liquidateLoan(loan_id: uint256):
        loan = self.loans[loan_id]
        require(loan.status == 1, "Loan is not active")
        require(block.timestamp > loan.endTime, "Loan repayment period has not expired")

        # Check if loan is undercollateralized
        if self.token.balanceOf(self.address) < loan.repaymentAmount:
            # Transfer collateral to liquidator
            self.token.transfer(msg.sender, loan.collateral)
            # Update loan status to liquidated
            self.loans[loan_id].status = 2

    # Function to extend loan duration
    @external
    def extendLoanDuration(loan_id: uint256, extension_days: uint256):
        loan = self.loans[loan_id]
        require(loan.status == 1, "Loan is not active")
        require(block.timestamp < loan.endTime, "Loan repayment period has expired")

        # Extend loan duration
        self.loans[loan_id].endTime += extension_days * 1 days

    # Function to calculate interest accrued on a loan
    @external
    @view
    def calculateInterest(loan_id: uint256) -> uint256:
        loan = self.loans[loan_id]
        time_elapsed = min(block.timestamp - loan.startTime, loan.duration * 1 days)
        interest_accrued = loan.amount * loan.interestRate / 100 * time_elapsed / (loan.duration * 1 days)
        return interest_accrued

    # Function to assess loan risk based on collateral value
    @external
    @view
    def assessLoanRisk(loan_id: uint256) -> uint256:
        loan = self.loans[loan_id]
        collateral_value = self._calculateCollateralValue(loan_id)
        loan_to_value_ratio = loan.amount / collateral_value * 100
        if loan_to_value_ratio < 150:
            return 1  # Low risk
        elif loan_to_value_ratio < 200:
            return 2  # Medium risk
        else:
            return 3  # High risk

    # Internal function to calculate collateral value
    @internal
    def _calculateCollateralValue(loan_id: uint256) -> uint256:
        # Simplified calculation for demonstration purposes
        loan = self.loans[loan_id]
        return loan.collateral * 2  # Assume collateral value is twice the collateral amount

    # Function to adjust interest rate based on loan risk
    @external
    def adjustInterestRate(loan_id: uint256, new_interest_rate: uint256):
        loan = self.loans[loan_id]
        require(loan.status == 1, "Loan is not active")
        require(msg.sender == loan.borrower, "Only borrower can adjust interest rate")
        risk_level = self.assessLoanRisk(loan_id)
        if risk_level == 1:
            require(new_interest_rate <= loan.interestRate, "Interest rate cannot increase for low-risk loans")
        elif risk_level == 3:
            require(new_interest_rate >= loan.interestRate, "Interest rate cannot decrease for high-risk loans")
        self.loans[loan_id].interestRate = new_interest_rate
