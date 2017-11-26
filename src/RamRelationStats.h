/*
 * Souffle - A Datalog Compiler
 * Copyright (c) 2013, 2015, Oracle and/or its affiliates. All rights reserved
 * Licensed under the Universal Permissive License v 1.0 as shown at:
 * - https://opensource.org/licenses/UPL
 * - <souffle root>/licenses/SOUFFLE-UPL.txt
 */

/************************************************************************
 *
 * @file RamRelationStats.h
 *
 * A set of utilities for extracting and handling statistical data on
 * the data stored within relations.
 *
 ***********************************************************************/

#pragma once

#include "BTree.h"
#include "RamTypes.h"

#include <limits>
#include <vector>

namespace souffle {

/** The type to reference indices */
typedef unsigned Column;

/**
 * A summary of statistical properties of a ram relation.
 */
class RamRelationStats {
    /** The arity - accurate */
    size_t arity;

    /** The number of tuples - accurate */
    uint64_t size;

    /** The sample size estimations are based on */
    uint32_t sample_size;

    /** The cardinality of the various components of the tuples - estimated */
    std::vector<uint64_t> cardinalities;

public:
    RamRelationStats() : arity(0), size(0), sample_size(0) {}

    RamRelationStats(size_t arity) : arity(arity), size(0), sample_size(0) {}

    RamRelationStats(uint64_t size, const std::vector<uint64_t>& cards)
            : arity(cards.size()), size(size), sample_size(0), cardinalities(cards) {}

    RamRelationStats(const RamRelationStats&) = default;
    RamRelationStats(RamRelationStats&&) = default;

    RamRelationStats& operator=(const RamRelationStats&) = default;
    RamRelationStats& operator=(RamRelationStats&&) = default;

    size_t getArity() const {
        return arity;
    }

    uint64_t getCardinality() const {
        return size;
    }

    uint32_t getSampleSize() const {
        return sample_size;
    }

    uint64_t getEstimatedCardinality(Column c) const {
        if (c >= cardinalities.size()) {
            return 0;
        }
        return cardinalities[c];
    }

    void print(std::ostream& out) const {
        out << cardinalities;
    }

    friend std::ostream& operator<<(std::ostream& out, const RamRelationStats& stats) {
        stats.print(out);
        return out;
    }
};

/**
 * A summary of statistical properties of a ram relation that also maintains counts for
 * distinct values.
 */
class DistinctValueStats : public RamRelationStats {
    /** write each column in its own set */
    std::vector<btree_set<RamDomain>> columns;

public:
    DistinctValueStats(size_t arity) : RamRelationStats(arity), columns(arity) {}

    void insert(const RamDomain* tuple) {
        for (std::size_t i = 0; i < getArity(); i++) {
            columns[i].insert(tuple[i]);
        }
    }

    const uint64_t getNumDistinct(Column c) const {
        return columns[c].size();
    }

    const btree_set<RamDomain>& getColumn(Column c) const {
        return columns[c];
    }

    void setColumn(Column c, const btree_set<RamDomain>& column) {
        if (c >= columns.size()) {
            columns.resize(c + 1);
        }
        columns[c] = column;
    }
};

}  // end of namespace souffle
