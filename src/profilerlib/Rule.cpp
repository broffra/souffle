/*
 * Souffle - A Datalog Compiler
 * Copyright (c) 2016, The Souffle Developers. All rights reserved
 * Licensed under the Universal Permissive License v 1.0 as shown at:
 * - https://opensource.org/licenses/UPL
 * - <souffle root>/licenses/SOUFFLE-UPL.txt
 */

#include "Rule.hpp"
#include <regex>

std::string Rule::toString() {
    std::ostringstream output;
    if (recursive) {
        output << "{" << name << "," << version << ":";
    } else {
        output << "{" << name << ":";
    }
    output << "[" << runtime << "," << num_tuples << "]}";
    return output.str();
}

void Rule::setLocator(std::string locator) {
    if (this->locator.empty()) {
        this->locator = locator;
    } else {
        this->locator += " " + locator;
    }
}

void Rule::setLineNumber() {
    if (locator.empty()) {
        return;
    }

    std::regex line_regex("\\[([0-9]+):[^\\]]*\\]");
    std::smatch line_match;

    if (std::regex_search(locator, line_match, line_regex)) {
        lineNumber = std::stoi(line_match[1]);
    }
}
