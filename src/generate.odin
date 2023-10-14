package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:slice"
import "core:io"
import "core:prof/spall"
import "core:encoding/json"
import "core:strconv"
import "core:math/rand"


main :: proc() {
	ctx, c_ok := spall.context_create("spall.prof")
	if !c_ok {
		fmt.eprintln("failed to create spall context")
		os.exit(1)
	}
	defer spall.context_destroy(&ctx)

	buf, b_ok := spall.buffer_create(make([]byte, 10000))
	if !b_ok {
		fmt.eprintln("failed to create spall buffer")
		os.exit(1)
	}
	defer spall.buffer_destroy(&ctx, &buf)
	defer spall.buffer_flush(&ctx, &buf)
	
	if len(os.args) < 2 {
		fmt.println("provide a number of pairs to generate")
		os.exit(0)
	}
	
	if len(os.args) < 3 {
		fmt.println("provide a seed")
		os.exit(0)
	}

	size, p_ok := strconv.parse_int(os.args[1])
	if !p_ok {
		fmt.eprintf("failed to parse number of pairs: %s\n", os.args[1])
		os.exit(1)
	}
	
	seed, s_ok := strconv.parse_u64(os.args[2])
	if !s_ok {
		fmt.eprintf("failed to parse seed: %s\n", os.args[2])
		os.exit(1)
	}

	sum: f64
	b, _ := strings.builder_make()
	
	random :: proc(seed: ^u64) -> f64 {
		res := rand.create(seed^)
		seed^ = rand.uint64(&res)
		return rand.float64(&res)
	}
	
	strings.write_string(&b, "{\"pairs\": [")
	for i := 0; i < size; i += 1 {
		x0 := (random(&seed) * 360) - 180
		x1 := (random(&seed) * 360) - 180
		y0 := (random(&seed) * 180) - 90
		y1 := (random(&seed) * 180) - 90
		sum += x0 + x1 + y0 + y1
		{
			spall.SCOPED_EVENT(&ctx, &buf, "marshal")
			bf: [20]byte
			strings.write_string(&b, "{\"x0\": ")
			strings.write_f64(&b, x0, 'f')
			strings.write_string(&b, ", \"y0\": ")
			strings.write_f64(&b, y0, 'f')
			strings.write_string(&b, ", \"x1\": ")
			strings.write_f64(&b, x1, 'f')
			strings.write_string(&b, ", \"y1\": ")
			strings.write_f64(&b, y1, 'f')
			strings.write_string(&b, "}")
		}
		if i < size - 1 {
			strings.write_string(&b, ", ")
		}
	}
	strings.write_string(&b, "]}")
	str := strings.to_string(b)
	{
		spall.SCOPED_EVENT(&ctx, &buf, "write_file")
		os.write_entire_file("input.json",  transmute([]byte)str)
	}
	
	fmt.printf("Mean: %v\n", sum / f64(size))
}

