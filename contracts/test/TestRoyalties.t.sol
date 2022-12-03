import {GBMFacet} from "../facets/GBMFacet.sol";
import "../interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "../facets/OwnershipFacet.sol";
import "../interfaces/IERC2981.sol";
import "../interfaces/IMultiRoyalty.sol";

import "forge-std/Test.sol";

import "../libraries/AppStorage.sol";

contract RoyaltyTests is IDiamondCut, Test {
    GBMFacet gFacet;
    address Diamond = 0xD5543237C656f25EEA69f1E247b8Fa59ba353306;
    address GHST = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
    uint256 auctionId = 264;

    bytes4[] GBMSELECTORS = generateSelectors("GBMFacet");

    function setUp() public {
        address owner = OwnershipFacet(Diamond).owner();
        vm.startPrank(owner);
        gFacet = new GBMFacet();
        FacetCut[] memory cut = new FacetCut[](1);
        cut[0] = FacetCut({facetAddress: address(gFacet), action: FacetCutAction.Replace, functionSelectors: GBMSELECTORS});
        IDiamondCut(Diamond).diamondCut(cut, address(0), "");
        vm.stopPrank();
    }

    function testRoyalties() public {
        Auction memory a = GBMFacet(Diamond).getAuctionInfo(auctionId);
        vm.startPrank(a.owner);
        vm.warp(a.info.endTime + 30);

        address[] memory royalties;
        uint256[] memory royaltyShares;
        uint256 _proceeds = a.highestBid - a.auctionDebt;

        if (IERC165(a.tokenContract).supportsInterface(0x2a55205a)) {
            // EIP-2981 is supported
            royalties = new address[](1);
            royaltyShares = new uint256[](1);
            (royalties[0], royaltyShares[0]) = IERC2981(a.tokenContract).royaltyInfo(a.info.tokenID, _proceeds);
        } else if (IERC165(a.tokenContract).supportsInterface(0x24d34933)) {
            // Multi Royalty Standard supported
            (royalties, royaltyShares) = IMultiRoyalty(a.tokenContract).multiRoyaltyInfo(a.info.tokenID, _proceeds);
        }
        //asserting only royalty balances
        uint256 balanceBefore = IGHST(GHST).balanceOf(royalties[0]);
        GBMFacet(Diamond).claim(auctionId);

        uint256 totalFees = _getFees(_proceeds, auctionId);
        //single royalty
        uint256 totalRoyalty = royaltyShares[0];
        totalFees += totalRoyalty;
        //owner is same as royalty in this case
        uint256 toOwner = _proceeds - totalFees;
        uint256 balanceAfter = IGHST(GHST).balanceOf(royalties[0]);

        assertEq(balanceBefore + toOwner, balanceAfter);

        //make sure there are no overflows
        assertEq(toOwner + totalFees, _proceeds);
    }

    function _getFees(uint256 _total, uint256 _auctionId) public view returns (uint256 total) {
        Auction memory a = GBMFacet(Diamond).getAuctionInfo(auctionId);

        //1.5% goes to pixelcraft
        uint256 pixelcraftShare = (_total * 15) / 1000;
        //1% goes to GBM
        uint256 GBM = (_total * 1) / 100;
        //0.5% to DAO
        uint256 DAO = (_total * 5) / 1000;

        //1% to treasury
        uint256 rarityFarming = (_total * 1) / 100;

        uint256 rem_ = pixelcraftShare + GBM + DAO + rarityFarming;
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }
}

interface IGHST {
    function balanceOf(address _user) external view returns (uint256);
}
