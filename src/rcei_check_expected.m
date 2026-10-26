function checks = rcei_check_expected(summary, expectedFile)
%RCEI_CHECK_EXPECTED Compare computed results with the supplied tolerances.
expected = readtable(expectedFile, 'TextType', 'string');
recording = string(summary(:, 1));
quantity = string(summary(:, 2));
actual = zeros(height(expected), 1);
for k = 1:height(expected)
    row = find(recording == expected.recording(k) & quantity == expected.quantity(k));
    if numel(row) ~= 1
        error('rcei:MissingResult', 'Expected one result for %s / %s.', ...
            expected.recording(k), expected.quantity(k));
    end
    actual(k) = summary{row, 3};
end
passed = isfinite(actual) & abs(actual - expected.expected) <= expected.tolerance;
checks = table(expected.recording, expected.quantity, actual, ...
    expected.expected, expected.tolerance, passed, 'VariableNames', ...
    {'recording', 'quantity', 'actual', 'expected', 'tolerance', 'passed'});
if ~all(passed)
    disp(checks(~passed, :));
    error('rcei:UnexpectedResult', '%d numerical checks failed.', sum(~passed));
end
end
