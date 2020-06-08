simple, fast interval searches for nim

This uses a binary search in a sorted list of intervals along with knowledge of the longest interval.
It works when the size of the largest interval is smaller than the average distance between intervals.
As that ratio of largest-size::mean-distance increases, the performance decreases.
On realistic (for my use-case) data, this is 1000 times faster to query results and >5000
times faster to check for presence than a brute-force method. 

Lapper also has a special case `seek` method when we know that the queries will be in order.
This method uses a cursor to indicate that start of the last search and does a linear search
from that cursor to find matching intervals. This gives an additional 2-fold speedup over
the `find` method.

API docs and examples in `nim-doc` format are available [here](https://brentp.github.io/nim-lapper/index.html)

See the `Performance` section for how large the intervals can be and still get a performance
benefit.

To use this, it's simply required that your type have a `start(m) int` and `stop(m) int` method to satisfy
the [concept](https://nim-lang.org/docs/manual.html#generics-concepts) used by `Lapper`

You can install this with `nimble install lapper`.

## Example

```nim
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

```


## Performance

The output of running `bench.nim` (with -d:release) which generates *200K intervals*
with positions ranging from 0 to 50 million and max lengths from 10 to 1M is:

| max interval size | lapper time | lapper seek time | brute-force time | speedup | seek speedup | each-seek speedup |
| ----------------- | ----------- | ---------------- | ---------------  | ------- | ------------ | ----------------- |
|10|0.06|0.04|387.44|6983.81|9873.11|9681.66|
|100|0.05|0.04|384.92|7344.32|10412.97|15200.84|
|1000|0.06|0.05|375.37|6250.23|7942.50|15703.24|
|10000|0.15|0.14|377.29|2554.61|2702.13|15942.76|
|100000|0.99|0.99|377.88|383.36|381.37|16241.61|
|1000000|12.52|12.53|425.61|34.01|33.96|17762.58|

Note that this is a worst-case scenario as we could also 
simulate a case where there are few long intervals instead of
many large ones as in this case. Even so, we get a 34X speedup with `lapper`.

Also note that testing for presence will be even faster than
the above comparisons as it returns true as soon as an overlap is found.
