#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
 	mkdir -p t/a t/b
 	touch t/a/e
 	echo -en "ABCDEF" > t/a/a
 	echo -en "ABCCEF" > t/b/b
 	echo -en "AAAAAA" > t/b/c
 	echo -en "012345678" > t/a/n
}

teardown() {
	cat t/trace.log
	rm -rf t/  # commentez pour garder les artefacts de tests
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

trace_run() {
	run --separate-stderr strace "$@"
}

@test "usage ok simple: lcp fichier fichier" {
	trun ./lcp t/a/a t/b/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
}

@test "usage nok mauvais narg: lcp a" {
	tsrun ./lcp t/a/a
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "usage nok mauvais arg: -c" {
	tsrun ./lcp -c t/a/a t/b/a
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "usage nok mauvais arg: -b NaN" {
	tsrun ./lcp -b abc t/a/a t/b/a
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "usage nok mauvais arg: lcp -b sans src dst" {
	tsrun ./lcp -b 2
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "usage nok mauvais arg: lcp -b src dst" {
	tsrun ./lcp -b t/a/a t/a/a
	[ "$status" -ne 0 ]
	[ "$stderr" != "" ]
}

@test "usage nok b zero: lcp -b 0 src dst" {
	tsrun ./lcp -b 0 t/a/a t/a/a
	[ "$status" -ne 0 ]
	[[ "$stderr" = *"negatif ou nul"* ]]
}

@test "usage nok b impair: lcp -b 1 src dst" {
	tsrun ./lcp -b 1 t/a/a t/a/a
	[ "$status" -ne 0 ]
	[[ "$stderr" == *"pair"* ]]
}

@test "usage ok b pair: lcp -b 2 src dst" {
	trun ./lcp -b 2 t/a/a t/a/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "bloc size read: lcp -b 2 src dst" {
	trun ./lcp -b 2 t/a/a t/b/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
	[[ "$trace" =~ read\(2\) ]]
}

@test "bloc size write: lcp -b 2 src dst" {
	TRACEALL=1 trun ./lcp -b 2 t/a/a t/b/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
	[[ "$trace" =~ write\(2\) ]]
}

@test "multiple src bad dst: dst_is_file" {
	trun ./lcp t/a/a t/a/e t/b/f
	[ "$status" -ne 0 ]
}

@test "multiple src bad dst: dst_is_missing" {
	trun ./lcp t/a/a t/a/e t/b/g
	[ "$status" -ne 0 ]
}

@test "dest file not exists" {
	trun ./lcp -b 6 t/a/a t/b/
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
}

@test "dest dir" {
	trun ./lcp -b 2 t/a/a t/b
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
}

@test "dest dir (trailing slash)" {
	trun ./lcp -b 2 t/a/a t/b/
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
}

@test "dest 1 bloc diff" {
	TRACEALL=1 trun ./lcp -b 2 t/a/a t/b/b
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/b
	[[ "$trace" =~ write\(2\) ]]
	[[ "$trace" =~ (.*write.*){1} ]]
}

@test "dest many bloc diff" {
	TRACEALL=1 trun ./lcp -b 2 t/a/a t/b/d
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/d
	[[ "$trace" =~ write\(2\) ]]
	[[ "$trace" =~ (.*write.*){2} ]]
}

@test "dest diff" {
	trun ./lcp t/a/a t/b/c
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/c
}

# Nouvelle implementation d'un ancien test. L'ancienne version etait incompatible avec le tp2.
# On verifie que vous n'ecrivez pas a plus de deux descripteurs (les deux bouts du tube) lorsque les fichiers sont identiques
@test "dest nodiff should not write to file (only to pipes)" {
	cp t/a/a t/b/a
	trace_run -f ./lcp t/a/a t/b/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
	fdcount=`echo "$stderr" | grep -E "\[.*write" | grep -v "resumed" | awk '{print $3}' | sort -u | wc -l`
	[[ fdcount -le 2 ]]
}

@test "bloc misalign" {
	trun ./lcp -b 4 t/a/a t/b/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
}

@test "bloc large" {
	trun ./lcp -b 1024 t/a/a t/b/a
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/a
}

@test "dst larger" {
	trun ./lcp t/a/a t/b/z
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
	diff t/a/a t/b/z
}

#
# TP2
#

# Je vous laisse l'ancienne version aussi
# @test "On fork un écrivain pour chaque fichier source" {
# 	trace_run ./lcp t/a/a t/a/a t/a/a t/b
# 	forks=`echo "$stderr" | grep "clone" | wc -l`
# 	[ "$forks" -eq 3 ]
# }

@test "On fork un écrivain pour chaque fichier source (inject)" {
	TRACEALL=1 TRACECHILD=1 trun ./lcp t/a/a t/a/a t/a/a t/b
	forks=`echo -e "$trace" | sed 's/ /\n/g' | grep -c fork`
	[[ $forks -eq 3 ]]
}

@test "reader sends src file size (size_t) to writer" {
	trun ./lcp t/a/e t/b
	[[ $trace =~ "write(8)" ]]
}

@test "reader sends read count (size_t) after file size" {
	TRACEALL=1 trun ./lcp t/a/a t/b
	[[ $trace =~ .*write\(8\).*write\(8\).* ]]
}

@test "reader sends checksum (uint32_t) after read count" {
	TRACEALL=1 trun ./lcp -b 16 t/a/a t/b
	[[ $trace =~ .*write\(8\).*write\(8\).*write\(4\).* ]]
}

@test "reader sends chunk if needed" {
	TRACEALL=1 trun ./lcp -b 16 t/a/a t/b
	[[ $trace =~ .*write\(8\).*write\(8\).*write\(4\).*write\(6\).* ]]
}

@test "writer receives src file size (size_t)" {
	trace_run -f ./lcp -b 6 t/a/e t/b
	fork_pid=`echo "$stderr" | grep clone | grep -Eo '[0-9]+'`
	echo "$stderr" | grep "$fork_pid\]" | sed 's/.*\[.*\] //' | grep -E 'read(.*, 8)'
}

@test "writer receives buffer size (size_t) from pipe" {
	trace_run -f ./lcp -b 6 t/a/a t/b
	fork_pid=`echo "$stderr" | grep clone | grep -Eo '[0-9]+'`
	echo "$stderr" | grep "$fork_pid\]" | sed 's/.*\[.*\] //' | grep -E 'read(.*, 6)'
}

# fichier de 9 octets et un buffer size de 6. Trois tours 6, 3, 0 octets chacun.
# file size, buffer_size, buffer_size, buffer_size
@test "writer receives buffer size (size_t) from pipe each block" {
	trace_run -f ./lcp -b 6 t/a/n t/b
	fork_pid=`echo "$stderr" | grep clone | cut -d ')' -f 2 | grep -Eo '[0-9]+'`
	reads=`echo "$stderr" | grep "$fork_pid\]" | sed 's/.*\[.*\] //' | grep -E '(^read\(|read resumed).*, 8\)' | wc -l`
	[ $reads -eq 4 ]
}

@test "writer receives buffer from pipe each block" {
	TRACECHILD=1 TRACEALL=1 trun ./lcp -b 6 t/a/n t/b
	echo "$trace" | grep -E 'read\(6\)'
	reads=`echo "$trace" | grep -E 'read\(6\)' | wc -l`
	[[ $trace =~ (.*read\(6\).*){2} ]]  # Once from pipe, then a second from file
}

# deux blocs
@test "writer receives checksum (uint32_t) from pipe each block" {
	trace_run -f ./lcp -b 6 t/a/n t/b
	fork_pid=`echo "$stderr" | grep clone | cut -d ')' -f 2 | grep -Eo '[0-9]+'`
	reads=`echo "$stderr" | grep "$fork_pid\]" | sed 's/.*\[.*\] //' | grep -E '(^read\(|read resumed).*, 4\)' | wc -l`
	echo "$stderr" | grep "$fork_pid\]" | sed 's/.*\[.*\] //' | grep -E '(^read\(|read resumed).*, 4\)'
	[ $reads -ge 2 ]
}

@test "writer sends wether it needs block to reader (int boolean (1 or 0))" {
	trace_run -f ./lcp -b 6 t/a/n t/b
	fork_pid=`echo "$stderr" | grep clone | cut -d ')' -f 2 | grep -Eo '[0-9]+'`
	writes=`echo "$stderr" | grep "$fork_pid\]" | sed 's/.*\[.*\] //' | grep -E '(^write|write resumed)' | grep -e '.1.0.0.0' | wc -l`
	[ "$writes" -ge 2 ]
}