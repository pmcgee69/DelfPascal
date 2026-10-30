// A natural sort in C++23, the same rules as ..\1-chunks.delf: a name is a run
// of chunks, digits or text; the first chunk that differs decides. Digits by
// value (kept as text, any length), more leading zeros first for the same
// value; text ignoring case; a run of digits before text. Checked against
// Windows' StrCmpLogicalW, which Explorer sorts with.
//
// std::variant is the sum type, and std::visit over two variants is the match
// on a pair that Delf doesn't have yet (compare_chunks).
//
//   bcc64x -O2 -std=c++23 natural_sort23.cpp -lshlwapi -o natural_sort23.exe

#include <algorithm>
#include <compare>
#include <cwctype>
#include <print>
#include <ranges>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

#include <windows.h>
#include <shlwapi.h>

struct Digits { std::wstring value; };
struct Text   { std::wstring value; };
using Chunk = std::variant<Digits, Text>;

template <class... Fs> struct overloaded : Fs... { using Fs::operator()...; };

// a name cut into its chunks: L"file10.txt" is Text{file}, Digits{10}, Text{.txt}
std::vector<Chunk> chunks(std::wstring_view s)
{
    std::vector<Chunk> out;
    for (std::size_t i = 0; i < s.size();) {
        const bool digits = std::iswdigit(s[i]);
        std::size_t j = i;
        while (j < s.size() && bool(std::iswdigit(s[j])) == digits) ++j;
        std::wstring run(s.substr(i, j - i));
        if (digits) out.push_back(Digits{std::move(run)});
        else        out.push_back(Text{std::move(run)});
        i = j;
    }
    return out;
}

// the digits without their leading zeros: 007 is 7, 000 is 0
std::wstring_view bare(std::wstring_view d)
{
    const auto first = d.find_first_not_of(L'0');
    return first == std::wstring_view::npos ? d.substr(d.size() - 1) : d.substr(first);
}

// by value: the shorter is smaller, then digit by digit; the same value, more leading zeros first
std::strong_ordering compare_digits(std::wstring_view a, std::wstring_view b)
{
    const auto x = bare(a), y = bare(b);
    if (auto c = x.size() <=> y.size(); c != 0) return c;
    if (auto c = x <=> y; c != 0) return c;
    return b.size() <=> a.size();
}

// ignoring case, as Delphi's CompareText: both upper-cased, then by code
std::strong_ordering compare_text(std::wstring_view a, std::wstring_view b)
{
    return std::lexicographical_compare_three_way(a.begin(), a.end(), b.begin(), b.end(),
        [](wchar_t p, wchar_t q) { return std::towupper(p) <=> std::towupper(q); });
}

std::strong_ordering compare_chunks(const Chunk& a, const Chunk& b)
{
    return std::visit(overloaded{
        [](const Digits& x, const Digits& y) { return compare_digits(x.value, y.value); },
        [](const Digits&,   const Text&)     { return std::strong_ordering::less; },
        [](const Text&,     const Digits&)   { return std::strong_ordering::greater; },
        [](const Text& x,   const Text& y)   { return compare_text(x.value, y.value); },
    }, a, b);
}

// the first chunk that differs decides; else the one with fewer chunks comes first
std::strong_ordering natural_compare(std::wstring_view a, std::wstring_view b)
{
    const auto x = chunks(a), y = chunks(b);
    for (const auto& [p, q] : std::views::zip(x, y))
        if (auto c = compare_chunks(p, q); c != 0) return c;
    return x.size() <=> y.size();
}

template <class Less>
std::vector<std::wstring> sorted(std::vector<std::wstring> names, Less less)
{
    std::ranges::sort(names, less);
    return names;
}

std::string narrow(const std::wstring& w) { return {w.begin(), w.end()}; }   // the names are ASCII

int main()
{
    const std::vector<std::wstring> names{
        L"file10.txt", L"file2.txt", L"File1.txt", L"file1.txt", L"file02.txt",
        L"a100", L"a20", L"a3b", L"a3a", L"x9z", L"x10y", L"version 1.10",
        L"version 1.9", L"item99999999999999999999", L"item100",
        L"ab1", L"abc", L"a-b", L"a1b", L"x001", L"x01"};

    const auto ours = sorted(names, [](const auto& a, const auto& b) { return natural_compare(a, b) < 0; });
    const auto theirs = sorted(names, [](const auto& a, const auto& b) { return StrCmpLogicalW(a.c_str(), b.c_str()) < 0; });
    for (const auto& [o, t] : std::views::zip(ours, theirs))
        std::println("{:<28}{:<28}{}", narrow(o), narrow(t), o == t ? "" : "<- differs");
}
