simple, fast interval searches for nim

This uses a binary search in a sorted list of intervals along with knowledge of the longest interval.
It works when the size of the largest interval is smaller than the average distance between intervals.
As that ratio of largest-size::mean-distance increases, the performance decreases.
On realistic (for my use-case) data, this is 500 times faster to query results and >2500
times faster to check for presence than a brute-force method.

See the `Performance` section for how large the intervals can be and still get a performance
benefit.

To use this, it's simply required that your type have a `start(m) int` and `stop(m) int` method to satisfy
the [concept](https://nim-lang.org/docs/manual.html#generics-concepts) used by `Lapper`

## Example

```nim
import lapper

# define an appropriate data-type. it must have a `start(m) int` and `stop(m) int` method.
type myinterval = tuple[start:int, stop:int]
proc start(m: myinterval): int {.inline.} = return m.start
proc stop(m: myinterval): int {.inline.} = return m.stop

# create some fake data
var ivs = new_seq[myinterval]()
for i in countup(0, 100, 10):
  ivs.add((i, i + 15))

# make the Lapper "data-structure"
var l = lapify(ivs)

assert l.overlaps(10, 20)
var notfound = not l.overlaps(200, 300)
assert notfound

var res = new_seq[myinterval]()

l.find(50, 70, res)
echo res
# @[(start: 40, stop: 55), (start: 50, stop: 65), (start: 60, stop: 75), (start: 70, stop: 85)]
```


## Performance

The output of running `bench.nim` (with -d:release) which generates *200K intervals*
with positions ranging from 0 to 50 million and max lengths from 10 to 10M is:

| max interval size | lapper time | brute-force time | speedup |
| ----------------- | ----------- | ---------------  | ------- |
|10|0.037535|29.64864|789.8931663780472|
|100|0.0383840000000002|29.82304|776.9654022509338|
|1000|0.04184799999999989|29.82697999999999|712.7456509271667|
|10000|0.06021600000000049|29.89744999999999|496.5034210176655|
|100000|0.2472209999999997|29.9892|121.3052289247274|
|1000000|2.077138|32.51190000000001|15.65225805892532|
|10000000|19.036699|52.31085|2.74789500007328|

Note that this is a worst-case scenario as we could also 
simulate a case where there are few long intervals instead of
many large ones as in this case.
