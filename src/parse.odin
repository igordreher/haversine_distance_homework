package main

import "core:os"
import "core:fmt"
import "core:strconv"

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("provide input json file")
		os.exit(1)
	}
	
	data, ok := os.read_entire_file_from_filename(os.args[1])
	if !ok {
		fmt.eprintf("failed to read file '%s'\n", os.args[1])
		os.exit(1)
	}

	v, p_ok := parse_json(data)
	if !p_ok {
		os.exit(1)
	}
	fmt.println(v)
}

parse_json :: proc(data: []byte) -> (v: Value, ok: bool) {
	parser: Parser
	parser.data = data
	v, ok = parse_value(&parser)
	using parser
	if !ok {
		start := max(cursor-30, 0)
		end := min(cursor+30, len(data)-1)
		fmt.eprintf("Error parsing json at %v:\n%s%s\n", cursor, data[start:cursor], data[cursor:end])
		for i := cursor-start ; i > 0; i -= 1 {
			fmt.eprint(" ")
		}
		fmt.println("^\n")
	}
	return v, ok
}

parse_value :: proc(using parser: ^Parser) -> (v: Value, ok: bool) {
	if len(data) <= cursor {
		return
	}
	switch data[parser.cursor] {
		case '{': return parse_object(parser) 
		case '0'..='9', '-': return parse_number(parser) 
		case 'a'..='Z': return parse_string(parser)
		case '[': return parse_array(parser)
	}
	return {}, false
}

parse_object :: proc(using parser: ^Parser) -> (obj: Object, ok: bool) {
	check_token(parser, '{') or_return
	obj = make(Object)

	for {
		skip_whitespaces(parser)
		str := parse_string(parser) or_return
		skip_whitespaces(parser)
	
		check_token(parser, ':') or_return
		skip_whitespaces(parser)
		v := parse_value(parser) or_return
		skip_whitespaces(parser)
		obj[str] = v

		if data[cursor] == ',' {
			cursor += 1
			continue
		}
		check_token(parser, '}') or_return
		break
	}

	return obj, true
}

parse_array :: proc(using parser: ^Parser) -> (v: Array, ok: bool) {
	check_token(parser, '[') or_return
	dyn_v := make([dynamic]Value)
	for {
		skip_whitespaces(parser)
		item := parse_value(parser) or_return
		append(&dyn_v, item)
		skip_whitespaces(parser)
		check_token(parser, ',') or_break
	}
	skip_whitespaces(parser)
	check_token(parser, ']') or_return
	return dyn_v[:], true
}

parse_number :: proc(using parser: ^Parser) -> (v: Number, ok: bool) {
	if len(data) <= cursor {
		return
	}
	if (data[cursor] < '0' || data[cursor] > '9') && data[cursor] != '-' {
		return v, false
	}
	cursor += 1

	size := 1
	dot: bool
	for {
		if len(data) <= cursor {
			return
		}
		if data[cursor] >= '0' && data[cursor] <= '9' {
			cursor += 1
			size += 1
			continue
		}
		if data[cursor] == '.' {
			if dot {
				return
			}
			dot = true
			cursor += 1
			size += 1
			continue
		}
		if data[cursor] == ' ' /* TODO: all whitespaces */ {
			cursor += 1
		}
		break
	}
	return strconv.parse_f64(cast(string)data[cursor-size:cursor])
}


parse_string :: proc(using parser: ^Parser) -> (v: string, ok: bool) {
	check_token(parser, '"') or_return

	str_size: int
	for data[cursor] != '"' {
		if len(data) <= cursor do return
		str_size += 1
		cursor += 1
	}
	cursor += 1
	
	return auto_cast data[cursor-str_size-1:cursor-1], true
}

skip_whitespaces :: proc(using parser: ^Parser) {
	for { // skip whitespaces
		if len(data) <= cursor {
			break
		}
		if data[cursor] == ' ' /* TODO: include all whitespaces */ {
			cursor += 1
		} else {
			break
		}
	}
}

check_token :: proc(using parser: ^Parser, token: byte) -> bool {
	if len(data) <= cursor || data[cursor] != token {
		return false
	}
	cursor += 1
	return true
}

Parser :: struct {
	cursor: int,
	data: []byte,
}

Value :: union {
	Object,
	Array,
	Number,
	string,
}

Object :: map[string]Value
Array :: []Value
Number :: f64

