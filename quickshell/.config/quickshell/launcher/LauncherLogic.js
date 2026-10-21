.pragma library

// Pure helpers for the launcher (text folding, calculator, URL test, Exec= parsing),
// kept free of QML types so tests/run.mjs can exercise them under node.

function fold(s) {
    var out = ""
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i)
        var d = c.normalize("NFD").charAt(0)
        out += (d === "\u0111" || d === "\u0110") ? "d" : d.toLowerCase()
    }
    return out
}

function calc(src) {
    var s = src.replace(/\*\*/g, "^").replace(/,/g, ".")
    var pos = 0
    function ws() { while (pos < s.length && s.charAt(pos) === " ") pos++ }
    function peek() { ws(); return s.charAt(pos) }
    function fail() { throw new Error("parse") }
    var fns = { sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin,
                acos: Math.acos, atan: Math.atan, ln: Math.log, log: Math.log10, abs: Math.abs,
                round: Math.round, floor: Math.floor, ceil: Math.ceil, exp: Math.exp }
    function primary() {
        var c = peek()
        if (c === "(") { pos++; var v = expr(); if (peek() !== ")") fail(); pos++; return v }
        var m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.slice(pos))
        if (m && c !== "") { pos += m[0].length; return parseFloat(m[0]) }
        var id = /^[a-z]+/i.exec(s.slice(pos))
        if (!id) fail()
        var name = id[0].toLowerCase()
        pos += name.length
        if (name === "pi") return Math.PI
        if (name === "e") return Math.E
        if (!Object.prototype.hasOwnProperty.call(fns, name)) fail()
        if (peek() !== "(") fail()
        pos++
        var arg = expr()
        if (peek() !== ")") fail()
        pos++
        return fns[name](arg)
    }
    function unary() {
        var c = peek()
        if (c === "-") { pos++; return -unary() }
        if (c === "+") { pos++; return unary() }
        return power()
    }
    // ^ binds tighter than a leading minus (-2^2 = -4) and is right-associative.
    function power() {
        var b = primary()
        if (peek() === "^") { pos++; return Math.pow(b, unary()) }
        return b
    }
    function term() {
        var v = unary()
        for (;;) {
            var c = peek()
            if (c === "*") { pos++; v *= unary() }
            else if (c === "/") { pos++; v /= unary() }
            else if (c === "%") { pos++; v %= unary() }
            else return v
        }
    }
    function expr() {
        var v = term()
        for (;;) {
            var c = peek()
            if (c === "+") { pos++; v += term() }
            else if (c === "-") { pos++; v -= term() }
            else return v
        }
    }
    try {
        var r = expr()
        ws()
        if (pos !== s.length || !isFinite(r)) return null
        return r
    } catch (e) {
        return null
    }
}

function formatNumber(n) {
    return typeof n === "number" ? String(Number(n.toPrecision(12))) : ""
}

function isUrl(q) {
    return /^(https?:\/\/)\S+$/i.test(q) || /^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(q)
}

// a shell. Respects single/double quotes and backslash escapes, expands %%
// to %, drops URL/file/other field codes, and substitutes %c (app name) /
// %k (desktop file path) when available, otherwise drops them.
function parseXdgExec(exec, entry) {
    var argv = []
    if (!exec) return argv
    var i = 0
    var n = exec.length
    var arg = ""
    var hasArg = false
    var inSingle = false
    var inDouble = false

    function flush() {
        if (hasArg) {
            argv.push(arg)
            arg = ""
            hasArg = false
        }
    }

    while (i < n) {
        var c = exec.charAt(i)

        if (inSingle) {
            if (c === "'") {
                inSingle = false
            } else {
                arg += c
            }
            hasArg = true
            i++
            continue
        }

        if (inDouble) {
            if (c === "\\" && i + 1 < n) {
                arg += exec.charAt(i + 1)
                hasArg = true
                i += 2
                continue
            }
            if (c === '"') {
                inDouble = false
            } else {
                arg += c
            }
            hasArg = true
            i++
            continue
        }

        if (c === "\\" && i + 1 < n) {
            arg += exec.charAt(i + 1)
            hasArg = true
            i += 2
            continue
        }

        if (c === "'") {
            inSingle = true
            hasArg = true
            i++
            continue
        }

        if (c === '"') {
            inDouble = true
            hasArg = true
            i++
            continue
        }

        if (c === " " || c === "\t" || c === "\n") {
            flush()
            i++
            continue
        }

        if (c === "%") {
            var code = exec.charAt(i + 1)
            if (code === "%") {
                arg += "%"
                hasArg = true
            } else if (code === "c") {
                if (entry && entry.name) {
                    arg += entry.name
                    hasArg = true
                }
            } else if (code === "f" || code === "F" || code === "u" || code === "U"
                    || code === "d" || code === "D" || code === "n" || code === "N"
                    || code === "i" || code === "v" || code === "m" || code === "k") {
                // Field codes with no local substitution: drop.
            } else {
                arg += c
                hasArg = true
                i++
                continue
            }
            i += 2
            continue
        }

        arg += c
        hasArg = true
        i++
    }
    flush()
    return argv
}
