#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
	mkdir -p t
	mkdir -p t/a t/b
	touch t/a/e
	touch t/b/f
	echo -en "ABCDEF" > t/a/a
	echo -en "ABCCEF" > t/b/b
	echo -en "AAAAAA" > t/b/c
	echo -en "AACDEE" > t/b/d
	head -c 4096 /dev/zero > t/a/4
}

teardown() {
	cat t/trace.log
	chmod -R 700 t
	rm -r t/
	true
}

# Lancer les tests avec `BATS_VALGRIND` active la detection des fuites

if [[ -n "$BATS_VALGRIND" ]]; then
	eval orig_"$(declare -f run)"
	run() {
		orig_run valgrind -q --leak-check=full "$@"
	}
fi

trun() {
	run ./inject "$@" 3>t/trace.log
	trace=`cat t/trace.log`
	trace=`echo $trace`
}

tsrun() {
	run --separate-stderr ./inject "$@" 3>t/trace.log
	trace=`cat t/trace.log`
	trace=`echo $trace`
}

@test "usage ok b pair: lcp -- -b dst" {
	echo "AAAAAA" > -b
	trun ./lcp -- -b t/b/
	[ "$status" -eq 0 ]
	diff -- -b t/b/-b
	rm -- -b
	[ "$output" = "" ]
}

@test "usage ok b pair: lcp -- -- dst" {
	echo "AAAAAA" > --
	trun ./lcp -- -- t/b/
	[ "$status" -eq 0 ]
	diff -- -- t/b/--
	rm -- --
	[ "$output" = "" ]
}

@test "src noent" {
	tsrun ./lcp t/kjasdhfkasdhf t/b/
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "src one of many noent" {
	tsrun ./lcp t/a/a t/kjasdhfkasdhf t/b/
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "4096 sources" {
	mkdir -p t/m/src t/m/dst
	for i in `seq 4096`; do echo "AAAA" > t/m/src/$i; done
	trun ./lcp t/m/src/* t/m/dst
	for i in `seq 4096`; do diff t/m/src/$i t/m/dst/$i; done
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "Missing intermediate dir" {
	tsrun ./lcp t/a/a t/b/c/a
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

# @test "Very large block" {
# 	trun ./lcp -b 2147483648 t/a/a t/b/
# 	[ "$status" -eq 0 ]
# 	[[ "$trace" =~ read\(2147483648\) ]]
# }

@test "usage nok b negatif: lcp -b -2 src dst" {
	tsrun ./lcp -b -2 t/a/a t/a/a
	[ "$status" -ne 0 ]
	[[ "$stderr" = *"negatif ou nul"* ]]
}

@test "Cannot read dst" {
	echo "AAAAAA" > t/b/x
	chmod -r t/b/x
	tsrun ./lcp t/a/a t/b/x
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "Cannot write dst" {
	echo "AAAAAA" > t/b/y
	chmod -w t/b/y
	tsrun ./lcp t/a/a t/b/y
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "Cannot modify dst dir" {
	mkdir -p t/x
	chmod -w t/x
	tsrun ./lcp t/a/a t/x/
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "Cannot read src" {
	echo "AAAAAA" > t/a/x
	chmod -r t/a/x
	tsrun ./lcp t/a/x t/b
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

