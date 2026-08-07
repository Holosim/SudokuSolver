// InputSource.h — where the puzzle text comes from.
//
// docs/SDD.md 2.7. RTVM-002, RTVM-003, RTVM-009.

#pragma once

#include <optional>
#include <string>
#include <string_view>

#include "InputFault.h"
#include "StdinChannel.h"

namespace sudoku::cli {

// Either the puzzle text or the reason it could not be obtained.
struct ReadResult {
    std::string                     text;
    std::optional<sudoku::InputFault> fault;   // SourceUnreadable (RTVM-009)
};

class InputSource {
public:
    explicit InputSource(StdinChannel& stdinChannel);

    // Reads from the file at 'path', or from the stdin channel when 'path'
    // is empty. Stops after kGridSize logical lines; content beyond that is
    // never read (docs/RTVM.md 7 I-2).
    //
    // A file that cannot be opened or read yields a SourceUnreadable fault
    // naming the path and the GetLastError code -- the wording is the
    // output layer's business (RTVM-009).
    [[nodiscard]] ReadResult readPuzzleText(std::string_view path);

private:
    StdinChannel& m_stdin;
};

} // namespace sudoku::cli
