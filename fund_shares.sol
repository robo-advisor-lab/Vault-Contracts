// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

// Import OpenZeppelin dependencies using a specific version
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";

/**
 * @title WETH ERC-4626 Vault
 * @dev This contract allows users to deposit WETH, mint proportional fund shares,
 *      and send WETH to a designated fund portfolio while relying on an external
 *      portfolio value update for tracking share value.
 */
contract WETHVault is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable weth;
    address public immutable fundPortfolio;
    mapping(address => bool) public admins; // Admins who can update portfolio value
    uint256 public portfolioValue; // Total fund value tracked externally

    event WithdrawalRequest(address indexed user, uint256 amount);

    constructor(
        address _weth,
        address _fundPortfolio,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        require(_weth != address(0), "WETH address cannot be zero");
        require(_fundPortfolio != address(0), "Fund portfolio address cannot be zero");
        
        weth = IERC20(_weth);
        fundPortfolio = _fundPortfolio;
        admins[msg.sender] = true; // Contract deployer is an admin by default
    }

    /**
     * @dev Allows an admin to update the total portfolio value (tracked externally).
     */
    function setPortfolioValue(uint256 _newValue) external {
        require(admins[msg.sender], "Not an admin");
        require(_newValue > 0, "Portfolio value must be positive");
        portfolioValue = _newValue;
    }

    /**
     * @dev Deposit WETH, mint proportional shares, and send WETH to the fund portfolio.
     * @param amount The amount of WETH to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        
        // Transfer WETH from user to this contract
        weth.safeTransferFrom(msg.sender, address(this), amount);
        
        // Forward WETH to fund portfolio (EOA account)
        weth.safeTransfer(fundPortfolio, amount);
        
        // Calculate shares to mint based on total portfolio value
        uint256 supply = totalSupply();
        uint256 shares = (supply == 0 || portfolioValue == 0) ? amount : (amount * supply) / portfolioValue;
        
        _mint(msg.sender, shares);
    }

    /**
     * @dev Withdraw WETH by burning vault shares.
     * @param shares The number of vault shares to redeem.
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0, "Shares must be greater than zero");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");

        uint256 supply = totalSupply();
        uint256 amount = (shares * portfolioValue) / supply; // Compute WETH equivalent

        _burn(msg.sender, shares);

        // Admin or bot must send WETH manually from fund portfolio (EOA) to user
        emit WithdrawalRequest(msg.sender, amount);
    }

    /**
     * @dev Returns the value of a single share based on fundPortfolio's total valuation.
     */
    function pricePerShare() external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? 1e18 : (portfolioValue * 1e18) / supply;
    }

    /**
     * @dev Adds or removes admin privileges.
     */
    function setAdmin(address admin, bool status) external {
        require(admins[msg.sender], "Not an admin");
        admins[admin] = status;
    }
}
