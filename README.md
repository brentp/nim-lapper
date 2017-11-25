simple, fast interval searches for nim

This uses a binary search in a sorted list of intervals along with knowledge of the longest interval.
It works when the size of the largest interval is smaller than the average distance between intervals.
As that ratio of largest-size::mean-distance increases, the performance decreases.
On realistic (for my use-case) data, this is 500 times faster to query results and >2500
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

## Example

```nim
import lapper
import strutils

# define an appropriate data-type. it must have a `start(m) int` and `stop(m) int` method.
#type myinterval = tuple[start:int, stop:int, val:int]
# if we want to modify the result, then we have to use a ref object type
type myinterval = ref object of RootObj
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
with positions ranging from 0 to 50 million and max lengths from 10 to 10M is:

| max interval size | lapper time | lapper seek time | brute-force time | speedup | seek speedup | seek_do speedup |
| ----------------- | ----------- | ---------------- | ---------------  | ------- | ------------ | --------------- |
|10|0.02257|0.01700699999999999|76.39568|3384.832964111652|4492.013876639033|5007.254375040962|
|100|0.02287899999999965|0.01534499999999994|72.81669000000001|3182.686743301767|4745.304007820156|5577.258731617381|
|1000|0.02739600000000131|0.02180900000000108|74.54980999999998|2721.193239888904|3418.304828281732|2846.064365885287|
|10000|0.05386900000000239|0.06077499999999958|73.23878999999998|1359.572110118932|1205.080872069115|2615.29745750614|
|100000|0.3015420000000013|0.2950440000000008|74.62886999999998|247.4907973018672|252.9414934721594|664.8037093455218|
|1000000|3.283310999999998|3.403959999999998|79.87128000000006|24.32644364179943|23.46422402143389|65.28466255963777|
|10000000|76.22971600000001|79.086713|147.3813899999999|1.933385006970246|1.863541730454772|3.983509485787777|


Note that this is a worst-case scenario as we could also 
simulate a case where there are few long intervals instead of
many large ones as in this case.

Also note that testing for presence will be even faster than
the above comparisons as it returns true as soon as an overlap is found.
