# Test fixtures

Data files used by the test suite. `TKTestUtils.DataFile('<name>')` resolves a
name to this folder, walking up from the test binary, so tests do not depend on
the working directory or on where the project was built.

Keep fixtures small and self-describing: a fixture is part of the test, and a
reader should be able to tell what a test expects without opening the data file
in a separate editor.
