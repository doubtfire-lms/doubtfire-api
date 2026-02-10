from importlib import util
import sys
from pathlib import Path

root_path = Path(__file__).resolve().parent.parent.parent
main_path = root_path / "app" / "models" / "concept_usage"
rules_path = main_path / "rules.json"
tests_path = root_path / "test_files" / "concept_usage_test_files"

sys.path.append(str(main_path))
import check_concept_usage

# [<test file>, <ruleset to test with>, <expected issues>]
tests = [
    # Tests by chapter
    # Test using the ruleset for the associated chapter (no issues),
    # a chapter in the future (no issues), and in the past (should have issues)
    ["chapter_02_sequence.cpp", "chapter_02_sequence", ""],
    ["chapter_02_sequence.cpp", "chapter_10_pointers_and_lists", ""],

    ["chapter_03_data.cpp", "chapter_03_data", ""],
    ["chapter_03_data.cpp", "chapter_10_pointers_and_lists", ""],
    ["chapter_03_data.cpp", "chapter_02_sequence", "Variable"],

    ["chapter_04_control_flow.cpp", "chapter_04_control_flow", ""],
    ["chapter_04_control_flow.cpp", "chapter_10_pointers_and_lists", ""],
    ["chapter_04_control_flow.cpp", "chapter_03_data", "ControlFlow"],
    ["chapter_04_control_flow.cpp", "chapter_02_sequence", "ControlFlow, Variable"],

    ["chapter_05_structuring_code.cpp", "chapter_05_structuring_code", ""],
    ["chapter_05_structuring_code.cpp", "chapter_10_pointers_and_lists", ""],
    ["chapter_05_structuring_code.cpp", "chapter_02_sequence", "Function, ControlFlow, Variable"],

    ["chapter_06_structuring_data.cpp", "chapter_06_structuring_data", ""],
    ["chapter_06_structuring_data.cpp", "chapter_10_pointers_and_lists", ""],
    ["chapter_06_structuring_data.cpp", "chapter_02_sequence", "Struct, Variable"],
    ["chapter_06_structuring_data.cpp", "chapter_05_structuring_code", "Struct"],

    ["chapter_07_handling_multiples.cpp", "chapter_07_handling_multiples", ""],
    ["chapter_07_handling_multiples.cpp", "chapter_10_pointers_and_lists", ""],
    ["chapter_07_handling_multiples.cpp", "chapter_02_sequence", "Array, Struct, Enum, Function, ControlFlow, Variable"],
    ["chapter_07_handling_multiples.cpp", "chapter_05_structuring_code", "Array, Struct, Enum"],

    ["chapter_08_member_functions.cpp", "chapter_08_member_functions", ""],
    ["chapter_08_member_functions.cpp", "chapter_07_handling_multiples", "Method"],
    ["chapter_08_member_functions.cpp", "chapter_02_sequence", "Method, Array, Struct, Variable"],

    ["chapter_09_generics_and_operators.cpp", "chapter_09_generics_and_operators", ""],
    ["chapter_09_generics_and_operators.cpp", "chapter_08_member_functions", "Template, OperatorOverload"],
    ["chapter_09_generics_and_operators.cpp", "chapter_02_sequence", "Template, OperatorOverload, Method, Array, Struct, Variable"],

    ["chapter_10_pointers_and_lists.cpp", "chapter_10_pointers_and_lists", ""],
    ["chapter_10_pointers_and_lists.cpp", "chapter_02_sequence", "Pointer, CppNew, Array, Function, ControlFlow, Variable"],
    ["chapter_10_pointers_and_lists.cpp", "chapter_05_structuring_code", "Pointer, CppNew, Array"],

    ["chapter_11_memory_deep_dive.cpp", "chapter_11_memory_deep_dive", ""],
    ["chapter_11_memory_deep_dive.cpp", "chapter_02_sequence", "CppNewArray, Pointer, CppNew, Template, Method, Array, Struct, Enum, Function, Exception, ControlFlow, Variable"],
    ["chapter_11_memory_deep_dive.cpp", "chapter_05_structuring_code", "CppNewArray, Pointer, CppNew, Template, Method, Array, Struct, Enum"],

    # Misc Checks
    ["stdin.cpp", "base_checks", "CppIO"],
    ["printf.cpp", "base_checks", "Printf"],
    ["global_const_unformatted.cpp", "base_checks", "FormattingConstant, FormattingVariable, GlobalVariable"],
    ["structuringdata_method_variable_formatting.cpp", "chapter_06_structuring_data", "FormattingVariable, Method"],
    ["new_and_goto.cpp", "chapter_06_structuring_data", "Goto, Pointer, CppNew"],
    ["missing_header.cpp", "chapter_03_data", "Struct"],
    ["missing_header.cpp", "chapter_06_structuring_data", ""],
]

print("============= Running Tests =============")
print("[" + (" " * len(tests)) + "]\r[", end="", flush=True)
for i, test in enumerate(tests):
    result = check_concept_usage.main_inner(tests_path / test[0], test[1], "id", rules_path)

    resultSet = set([x.strip() for x in result.split(",")])
    expectedSet = set([x.strip() for x in test[2].split(",")])

    assert resultSet == expectedSet, f"\n\nFailed on test {i}, for file {test[0]}, ruleset {test[1]}. \nExpected result: {test[2]}\nRecieved       : {result}"

    print("=", end="", flush=True)
print("\r============= Completed Tests =============")
