// Parser.cpp — see Parser.h.
//
// SCAFFOLD ONLY. Line splitting (LF/CRLF, optional trailing newline,
// whitespace stripping), the shape / character / contradiction precedence
// and the fault detail each case carries are implemented under their own
// issue.
//
// TODO(RTVM-100, RTVM-101, RTVM-102, RTVM-103, RTVM-104, RTVM-105,
//      RTVM-106): real parse and validation.

#include "Parser.h"

#include <utility>

namespace sudoku {

ParseResult ParseResult::success(Grid g)
{
    ParseResult r;
    r.m_ok = true;
    r.m_grid = std::move(g);
    return r;
}

ParseResult ParseResult::failure(InputFault f)
{
    ParseResult r;
    r.m_ok = false;
    r.m_fault = std::move(f);
    return r;
}

bool ParseResult::ok() const
{
    return m_ok;
}

const Grid& ParseResult::grid() const
{
    return m_grid;
}

const InputFault& ParseResult::fault() const
{
    return m_fault;
}

ParseResult parseGrid(std::string_view text)
{
    static_cast<void>(text);

    // Placeholder: every input is reported as ending early, which is the
    // safest lie for a scaffold — nothing reaches the solver.
    InputFault fault{};
    fault.kind = FaultKind::MissingLine;
    fault.line = 1;
    return ParseResult::failure(fault);
}

} // namespace sudoku
