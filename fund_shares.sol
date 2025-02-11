// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

// Import OpenZeppelin dependencies using a specific version
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";

/**
 * @title WETH ERC-4626 Vault
 * @dev This contract allows users to deposit WETH, mint proportional fund shares,
 *      and send WETH to a designated fund portfolio.
 */
contract WETHVault is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable weth;
    address public immutable fundPortfolio;

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
    }

    /**
     * @dev Deposit WETH, mint proportional shares, and send WETH to the fund portfolio.
     * @param amount The amount of WETH to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        
        // Transfer WETH from user to this contract
        weth.safeTransferFrom(msg.sender, address(this), amount);
        
        // Mint proportional shares
        uint256 shares = _convertToShares(amount);
        _mint(msg.sender, shares);
        
        // Forward WETH to fund portfolio (user pays gas)
        weth.safeTransfer(fundPortfolio, amount);
    }

    /**
     * @dev Calculate the equivalent amount of shares for a given amount of WETH.
     * @param assets The amount of WETH being deposited.
     * @return shares The calculated shares.
     */
    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply(); // Total shares supply
        uint256 totalAssets = weth.balanceOf(address(this)); // Total underlying assets

        return (supply == 0 || totalAssets == 0) ? assets : (assets * supply) / totalAssets;
    }

    /**
     * @dev Returns the value of a single share in terms of WETH.
     */
    function pricePerShare() external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? 1e18 : (weth.balanceOf(address(this)) * 1e18) / supply;
    }
}
