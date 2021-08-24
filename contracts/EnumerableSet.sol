// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./interfaces/IRegistry.sol";

contract EnumerableSet {
    struct LendingSet {
        IRegistry.Lending[] _values;
        mapping(uint256 => uint256) _indexes;
    }

    struct RentingSet {
        IRegistry.Renting[] _values;
        mapping(uint256 => uint256) _indexes;
    }

    // ! public not allowed for structs
    LendingSet private lendingSet;
    RentingSet private rentingSet;

    function add(IRegistry.Lending memory value, uint256 lendingID)
        internal
        returns (bool)
    {
        if (!lendingSetContains(lendingID)) {
            lendingSet._values.push(value);
            lendingSet._indexes[lendingID] = lendingSet._values.length;
            return true;
        } else {
            return false;
        }
    }

    function remove(IRegistry.Lending memory value, uint256 lendingID)
        internal
        returns (bool)
    {
        uint256 valueIndex = lendingSet._indexes[lendingID];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = lendingSet._values.length - 1;
            IRegistry.Lending memory lastvalue = lendingSet._values[lastIndex];
            lendingSet._values[toDeleteIndex] = lastvalue;
            lendingSet._indexes[lendingID] = toDeleteIndex + 1; // All indexes are 1-based
            lendingSet._values.pop();
            delete lendingSet._indexes[lendingID];
            return true;
        } else {
            return false;
        }
    }

    function lendingSetContains(uint256 lendingID)
        internal
        view
        returns (bool)
    {
        return lendingSet._indexes[lendingID] != 0;
    }

    function add(IRegistry.Renting memory value, uint256 rentingID)
        internal
        returns (bool)
    {
        if (!rentingSetContains(rentingID)) {
            rentingSet._values.push(value);
            rentingSet._indexes[rentingID] = rentingSet._values.length;
            return true;
        } else {
            return false;
        }
    }

    function remove(IRegistry.Renting memory value, uint256 rentingID)
        internal
        returns (bool)
    {
        uint256 valueIndex = rentingSet._indexes[rentingID];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = rentingSet._values.length - 1;
            IRegistry.Renting memory lastvalue = rentingSet._values[lastIndex];
            rentingSet._values[toDeleteIndex] = lastvalue;
            rentingSet._indexes[rentingID] = toDeleteIndex + 1;
            rentingSet._values.pop();
            delete rentingSet._indexes[rentingID];
            return true;
        } else {
            return false;
        }
    }

    function rentingSetContains(uint256 rentingID)
        internal
        view
        returns (bool)
    {
        return rentingSet._indexes[rentingID] != 0;
    }
}
