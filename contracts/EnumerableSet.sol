// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "./interfaces/IRegistry.sol";

contract EnumerableSet {
    struct LendingSet {
        IRegistry.Lending[] _values;
        // lendingID -> index
        mapping(uint256 => uint256) _indexes;
        // index -> lendingID
        mapping(uint256 => uint256) _reverseIndexes;
    }

    struct RentingSet {
        IRegistry.Renting[] _values;
        // rentingID -> index
        mapping(uint256 => uint256) _indexes;
        // index -> rentingID
        mapping(uint256 => uint256) _reverseIndexes;
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
            lendingSet._reverseIndexes[lendingSet._values.length] = lendingID;
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

    function lendingSetAt(uint256 lendingID)
        internal
        view
        returns (IRegistry.Lending memory)
    {
        return lendingSet._values[lendingSet._indexes[lendingID] - 1];
    }

    function lendingSetAtIndex(uint256 index)
        internal
        view
        returns (IRegistry.Lending memory)
    {
        return lendingSet._values[index];
    }

    function lendingReverseIndex(uint256 index)
        internal
        view
        returns (uint256)
    {
        return lendingSet._reverseIndexes[index];
    }

    function lendingSetLength() internal view returns (uint256 len) {
        len = lendingSet._values.length;
    }

    function add(IRegistry.Renting memory value, uint256 rentingID)
        internal
        returns (bool)
    {
        if (!rentingSetContains(rentingID)) {
            rentingSet._values.push(value);
            rentingSet._indexes[rentingID] = rentingSet._values.length;
            rentingSet._reverseIndexes[rentingSet._values.length] = rentingID;
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

    function rentingSetAt(uint256 rentingID)
        internal
        view
        returns (IRegistry.Renting memory)
    {
        return rentingSet._values[rentingSet._indexes[rentingID] - 1];
    }

    function rentingSetAtIndex(uint256 index)
        internal
        view
        returns (IRegistry.Renting memory)
    {
        return rentingSet._values[index];
    }

    function rentingReverseIndex(uint256 index)
        internal
        view
        returns (uint256)
    {
        return rentingSet._reverseIndexes[index];
    }

    function rentingSetLength() internal view returns (uint256 len) {
        len = rentingSet._values.length;
    }
}
