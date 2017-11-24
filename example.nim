import lapper
import strutils

# define an appropriate data-type. it must have a `start(m) int` and `stop(m) int` method.
#type myinterval = tuple[start:int, stop:int, val:int]
# if we want to modify the result, then we have to use a ref object type
type myinterval = ref object
  start: int
  stop: int
  val: int

proc start(m: myinterval): int {.inline.} = return m.start
proc stop(m: myinterval): int {.inline.} = return m.stop
proc `$`(m:myinterval): string = return "(start:$#, stop:$#, val:$#)" % [$m.start, $m.stop, $m.val]

# create some fake data
var ivs = new_seq[myinterval]()
for i in countup(0, 100, 10):
  ivs.add(myinterval(start:i, stop:i + 15, val:0))

# make the Lapper "data-structure"
var l = lapify(ivs)
var empty:seq[myinterval]

assert l.find(10, 20, empty)
var notfound = not l.find(200, 300, empty)
assert notfound

var res = new_seq[myinterval]()

# find is the more general case, l.seek gives a speed benefit when consecutive queries are in order.
echo l.find(50, 70, res)
echo res
# @[(start: 40, stop: 55, val:0), (start: 50, stop: 65, val: 0), (start: 60, stop: 75, val: 0), (start: 70, stop: 85, val: 0)]
for r in res:
  r.val += 1

# or we can do a function on each overlapping interval
l.each_seek(50, 60, proc(a:myinterval) = inc(a.val))
# or
l.each_find(50, 60, proc(a:myinterval) = a.val += 10)

discard l.seek(50, 70, res)
echo res
#@[(start:40, stop:55, val:12), (start:50, stop:65, val:12), (start:60, stop:75, val:1)]
