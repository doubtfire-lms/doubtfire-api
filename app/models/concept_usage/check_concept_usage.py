#!/usr/bin/env python3

import json
import subprocess
import sys
from dataclasses import dataclass
from typing import Dict, List, Set
import re
import traceback
import os.path

# ==================== Constants ======================
RULES_PATH = "rules.json"

# Return codes
SUCCESS = 0
CODE_HAD_ISSUES = 32
CODE_CHECKING_FAILED = 64

# Removes all output except "matched" messages
# No user code should be visible in the output
CLANG_QUERY_PREAMBLE = """\
set traversal IgnoreUnlessSpelledInSource
disable output diag
disable output print
disable output detailed-ast
disable output dump
"""

# ==================== Clang Query Utils ======================

# Run clang-query and return the result

# Note: it deliberately ignores any stderr output,
# since we can't guarantee student's code will parse perfectly
# on our system (they could have their own include file, etc).
# Clang does a best effort parse in these cases, seems acceptable.

# Syntax errors for the `match` queries are handled later
# when the result is sanity checked, by comparing
# the count of successful match results with the expected number

# clang-query return code isn't useful either from what I can tell
def clang_query(source_file: str, query: str) -> str:
    full_query = CLANG_QUERY_PREAMBLE + query + "\n"

    result = subprocess.run(
        ["clang-query", source_file, "--"],
        input=full_query,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    return result.stdout

# Extract "0 matches, 1 match, etc"
def clang_query_extract_matches(output: List[str]) -> List[int]:
    pattern = re.compile(r'(\d+)\s+match(?:es)?')
    extracted_numbers = []

    for line in output:
        match = pattern.search(line)
        if match:
            number = int(match.group(1))
            extracted_numbers.append(number)

    return (extracted_numbers)

# ==================== Rule Loading ======================

@dataclass
class MatchQuerySet:
    queries: List[str]
    id: str
    description: str

def load_rules(path: str) -> Dict:
    with open(path, "r") as f:
        return json.load(f)

# Recursively include all the MatchQuerySets for the chosen ruleset (e.g chapter)
def resolve_rules(
    rules: Dict,
    ruleset: str
) -> List[MatchQuerySet]:
    chapter = rules[ruleset]
    matches: List[MatchQuerySet] = []

    for include in chapter.get("includes", []):
        matches.extend(resolve_rules(rules, include))

    for rule in chapter.get("rules", []):
        matches.append(MatchQuerySet(**rule))

    return matches

# ==================== Main Logic ======================

def check_usage(source_file: str, match_query_sets: List[MatchQuerySet]) -> None:
    # Run every match query in one go
    # We'll then split it up afterwards

    # Start by joining them all up
    combined_query = "\n".join(["\n".join([f"match {y}" for y in x.queries]) for x in match_query_sets])

    # Get the results from clang-query
    output = clang_query(source_file, combined_query)
    # Find the number of matches for each query
    match_counts = clang_query_extract_matches(output.split("\n"))
    # There should be the same number as there were match statements
    expected_match_length = sum([len(x.queries) for x in match_query_sets])

    if len(match_counts) != expected_match_length:
        # If not, something is wrong, abort checking
        print(f"Error: Mismatch between expected result count and clang-query output.", file=sys.stderr)
        print(f"Expected {expected_match_length} match counts, got {len(match_counts)}.", file=sys.stderr)
        print("There is likely a syntax error in the queries - see output below.", file=sys.stderr)
        print(f"\n==== clang-query Input ====\n{combined_query}\n============================", file=sys.stderr)
        print(f"\n==== clang-query Output ====\n{output}\n============================", file=sys.stderr)
        sys.exit(CODE_CHECKING_FAILED)

    # Now we can step through and pair up each match count with its associated MatchQuerySet
    idx = 0
    matched = []
    for matchQuerySet in match_query_sets:
        total_matches = sum(match_counts[idx : idx + len(matchQuerySet.queries)])
        idx += len(matchQuerySet.queries)

        if total_matches > 0:
            matched.append(matchQuerySet)

    return matched

# ==================== Output Formatting ======================

def format_output_ids(matched: List[MatchQuerySet]) -> str:
    return ", ".join([x.id for x in matched])

def format_output_descriptions(matched: List[MatchQuerySet]) -> str:
    return "\n".join([x.description for x in matched])

# =========== Main Real (extracted so it can be tested...) ===========

def main_inner(source_file: str, ruleset: str, output_style: str, rules_path: str) -> str:
    rules = load_rules(rules_path)
    match_query_sets = resolve_rules(rules, ruleset)

    matches = check_usage(source_file, match_query_sets)

    if output_style == "id":
        return format_output_ids(matches)
    else:
        return format_output_descriptions(matches)

# ==================== Command Line Usage ======================

def main() -> None:
    try:
        if len(sys.argv) != 4:
            print(f"Usage: {sys.argv[0]} <source-file> <rules> <output-style {{id=ID's only (comma delimited)|desc=Descriptions only (newline delimited)}}>")
            sys.exit(CODE_CHECKING_FAILED)

        source_file = sys.argv[1]
        ruleset = sys.argv[2]
        output_style = sys.argv[3]

        # check inputs
        assert os.path.isfile(RULES_PATH), f"Rule set file doesn't exist {RULES_PATH}"
        assert os.path.isfile(source_file), f"Input source file doesn't exist: {source_file}"
        assert output_style=="id" or output_style == "desc", f"Invalid output-style {output_style}"

        output = main_inner(source_file, ruleset, output_style, RULES_PATH)

        # Print the actual result on stdout
        print(output)

        if len(output) > 0:
            sys.exit(CODE_HAD_ISSUES)

    except Exception as e:
        print("Error:", traceback.format_exc(), file=sys.stderr)
        sys.exit(CODE_CHECKING_FAILED)

    sys.exit(SUCCESS)

if __name__ == "__main__":
    main()
