function space() {
    while (substr(document, position, 1) ~ /^[ \t\r\n]$/) position++
}

function escaped(    escape) {
    escape = substr(document, position++, 1)
    if (escape != "u") return escape ~ /^["\\\/bfnrt]$/
    if (substr(document, position, 4) !~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) return 0
    position += 4
    return 1
}

function quoted(    start, character) {
    if (substr(document, position++, 1) != "\"") return 0
    start = position
    while (position <= length(document)) {
        character = substr(document, position++, 1)
        if (character == "\"") {
            token = substr(document, start, position - start - 1)
            return 1
        }
        if (character ~ /[[:cntrl:]]/) return 0
        if (character == "\\" && !escaped()) return 0
    }
    return 0
}

function primitive(    remaining) {
    remaining = substr(document, position)
    if (match(remaining, /^(true|false|null|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?)/) != 1) return 0
    position += RLENGTH
    return 1
}

function member(depth,    key) {
    if (!quoted()) return 0
    key = token
    space()
    if (substr(document, position++, 1) != ":") return 0
    space()
    if (depth == 1 && key == field) {
        if (!quoted() || ++found != 1) return 0
        digest = token
        return 1
    }
    return value(depth)
}

function container(depth, opening,    closing, character) {
    closing = opening == "{" ? "}" : "]"
    position++
    space()
    if (substr(document, position, 1) == closing) {
        position++
        return 1
    }
    while (position <= length(document)) {
        if (opening == "{") {
            if (!member(depth)) return 0
        } else if (!value(depth)) return 0
        space()
        character = substr(document, position++, 1)
        if (character == closing) return 1
        if (character != ",") return 0
        space()
    }
    return 0
}

function value(depth,    character) {
    if (depth > 64) return 0
    space()
    character = substr(document, position, 1)
    if (character == "{" || character == "[") return container(depth + 1, character)
    if (character == "\"") return quoted()
    return primitive()
}

{ document = document $0 "\n" }

END {
    position = 1
    space()
    if (substr(document, position, 1) != "{" || !value(0)) exit 1
    space()
    if (position <= length(document) || found != 1) exit 1
    if (length(digest) != 64 || digest ~ /[^0-9a-f]/) exit 1
    print digest
}
