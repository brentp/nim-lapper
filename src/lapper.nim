## This module provides a simple data-structure for fast interval searches. It does not use an interval tree,
## instead, it operates on the assumption that most intervals are of similar length; or, more exactly, that the
## longest interval in the set is not long compared to the average distance between intervals. On any dataset
## where that is not the case, this method will not perform well. For cases where this holds true (as it often
## does with genomic data), we can sort by start and use binary search on the starts, accounting for the length
## of the longest interval. The advantage of this approach is simplicity of implementation and speed. In realistic
## tests queries returning the overlapping intervals are 1000 times faster than brute force and queries that merely
## check for the overlaps are > 5000 times faster.
##
## The main methods are `find` and `seek` where the latter uses a cursor and is very fast for cases when the queries
## are sorted. This is another innovation in this library that allows an addition ~50% speed improvement when
## consecutive queries are known to be in sort order.
##
## For both find and seek, if the given intervals parameter is nil, the function will return a boolean indicating if
## any intervals in the set overlap the query. This is much faster than modifying the
## intervals.
##
## The example below shows off most of the API of `Lapper`.
##
## .. code-block:: nim
##   import lapper
##   type myinterval = ref object
##      start: int
##      stop: int
##      val: int
##    
##    proc start(m: myinterval): int {.inline.} = return m.start
##    proc stop(m: myinterval): int {.inline.} = return m.stop
##    proc `$`(m:myinterval): string = return "(start:$#, stop:$#, val:$#)" % [$m.start, $m.stop, $m.val]
##    
##  create some fake data
## .. code-block:: nim
##  var ivs = new_seq[myinterval]()
##  for i in countup(0, 100, 10):
##    ivs.add(myinterval(start:i, stop:i + 15, val:0))

##  make the Lapper "data-structure"

## .. code-block:: nim
##  l = lapify(ivs)
##  empty:seq[myinterval]
    
## .. code-block:: nim
##  l.find(10, 20, empty)
##  notfound = not l.find(200, 300, empty)
##  assert notfound
    
## .. code-block:: nim
##  res = new_seq[myinterval]()
 
##  find is the more general case, l.seek gives a speed benefit when consecutive queries are in order.

## .. code-block:: nim
##  echo l.find(50, 70, res)
##  echo res
##  # @[(start: 40, stop: 55, val:0), (start: 50, stop: 65, val: 0), (start: 60, stop: 75, val: 0), (start: 70, stop: 85, val: 0)]
##  for r in res:
##     r.val += 1
 
## or we can do a function on each overlapping interval

## .. code-block:: nim
##   l.each_seek(50, 60, proc(a:myinterval) = inc(a.val))

## or

## .. code-block:: nim
##   l.each_find(50, 60, proc(a:myinterval) = a.val += 10)
 
## .. code-block:: nim
##   discard l.seek(50, 70, res)
##   echo res
##   # @[(start:40, stop:55, val:12), (start:50, stop:65, val:12), (start:60, stop:75, val:1)]
import algorithm

type

  Interval* = concept i
    ## An object/tuple must implement these 2 methods to use this module
    start(i) is int
    stop(i) is int

  Lapper*[T] = object
    ## Lapper enables fast interval searches
    intervals: seq[T]
    max_len*: int
    cursor: int ## `cursor` is used internally by ordered find

template overlap*[T:Interval](a: T, start:int, stop:int): bool =
  ## overlap returns true if half-open intervals overlap
  #return a.start < stop and a.stop > start
  a.stop > start and a.start < stop


proc iv_cmp[T:Interval](a, b: T): int =
    if a.start < b.start: return -1
    if b.start < a.start: return 1
    return cmp(a.stop, b.stop)


proc lapify*[T:Interval](ivs:var seq[T]): Lapper[T] =
  ## create a new Lapper object; ivs will be sorted.
  sort(ivs, iv_cmp)
  result = Lapper[T](max_len: 0, intervals:ivs)
  for iv in ivs:
    if iv.stop - iv.start > result.max_len:
      result.max_len = iv.stop - iv.start

proc lowerBound[T:Interval](a: var seq[T], start: int): int =
  result = a.low
  var count = a.high - a.low + 1
  var step, pos: int
  while count != 0:
    step = count div 2
    pos = result + step
    if a[pos].start < start:
      result = pos + 1
      count -= step + 1
    else:
      count = step

proc len*[T:Interval](L:Lapper[T]): int {.inline.} =
  ## len returns the number of intervals in the Lapper
  L.intervals.len

proc empty*[T:Interval](L:Lapper[T]): bool {.inline.} =
  return L.intervals.len == 0

iterator find*[T:Interval](L:var Lapper[T], start:int, stop:int): T =
  ## fill ivs with all intervals in L that overlap start .. stop.
  #if ivs.len != 0: ivs.set_len(0)
  shallow(L.intervals)
  let off = lowerBound(L.intervals, start - L.max_len)
  for i in off..L.intervals.high:
    let x = L.intervals[i]
    if likely(x.overlap(start, stop)):
      yield x
    elif x.start >= stop: break

proc find*[T:Interval](L:var Lapper[T], start:int, stop:int, ivs:var seq[T]): bool =
  ## fill ivs with all intervals in L that overlap start .. stop.
  #if ivs.len != 0: ivs.set_len(0)
  shallow(L.intervals)
  let off = lowerBound(L.intervals, start - L.max_len)
  var n = 0
  for i in off..L.intervals.high:
    let x = L.intervals[i]
    if x.overlap(start, stop):
      if n < ivs.len:
        ivs[n] = x
      else:
        ivs.add(x)
      n += 1
    elif x.start >= stop: break
  if ivs.len > n:
    ivs.setLen(n)
  return len(ivs) > 0

proc count*[T:Interval](L:var Lapper[T], start:int, stop:int): int =
  ## fill ivs with all intervals in L that overlap start .. stop.
  shallow(L.intervals)
  let off = lowerBound(L.intervals, start - L.max_len)
  for i in off..L.intervals.high:
    let x = L.intervals[i]
    if x.overlap(start, stop):
      result.inc
    elif x.start >= stop: break

proc each_find*[T:Interval](L:var Lapper[T], start:int, stop:int, fn: proc (v:T)) =
  ## call fn(x) for each interval x in L that overlaps start..stop
  let off = lowerBound(L.intervals, start - L.max_len)
  for i in off..L.intervals.high:
    let x = L.intervals[i]
    if x.overlap(start, stop):
      fn(x)
    elif x.start >= stop: break

iterator seek*[T:Interval](L:var Lapper[T], start:int, stop:int): T =
  if L.cursor == 0 or L.intervals[L.cursor].start > start:
    L.cursor = lowerBound(L.intervals, start - L.max_len)
  while (L.cursor + 1) < L.intervals.high and L.intervals[L.cursor + 1].start < (start - L.max_len):
    L.cursor += 1
  let old_cursor = L.cursor
  for i in L.cursor..L.intervals.high:
    let x = L.intervals[i]
    if x.overlap(start, stop):
      yield x
    elif x.start >= stop: break
  L.cursor = old_cursor

proc seek*[T:Interval](L:var Lapper[T], start:int, stop:int, ivs:var seq[T]): bool =
  ## fill ivs with all intervals in L that overlap start .. stop inclusive.
  ## this method will work when queries to this lapper are in sorted (start) order
  ## it uses a linear search from the last query instead of a binary search.
  ## if ivs is nil, then this will just return true if it finds an interval and false otherwise
  if ivs.len != 0: ivs.set_len(0)
  if L.cursor == 0 or L.intervals[L.cursor].start > start:
    L.cursor = lowerBound(L.intervals, start - L.max_len)
  let old_cursor = L.cursor
  while (L.cursor + 1) < L.intervals.high and L.intervals[L.cursor + 1].start < (start - L.max_len):
    L.cursor += 1
  for i in L.cursor..L.intervals.high:
    let x = L.intervals[i]
    if x.overlap(start, stop):
      ivs.add(x)
    elif x.start >= stop: break
  L.cursor = old_cursor
  return ivs.len != 0

proc each_seek*[T:Interval](L:var Lapper[T], start:int, stop:int, fn:proc (v:T)) {.inline.} =
  ## call fn(x) for each interval x in L that overlaps start..stop
  ## this assumes that subsequent calls to this function will be in sorted order
  if L.cursor == 0 or L.cursor >= L.intervals.high or L.intervals[L.cursor].start > start:
    L.cursor = lowerBound(L.intervals, start - L.max_len)
  while (L.cursor + 1) < L.intervals.high and L.intervals[L.cursor + 1].start < (start - L.max_len):
    L.cursor += 1
  let old_cursor = L.cursor
  for i in L.cursor..L.intervals.high:
    let x = L.intervals[i]
    if x.start >= stop: break
    elif x.stop > start:
      fn(x)
  L.cursor = old_cursor

iterator items*[T:Interval](L: Lapper[T]): T =
  for i in L.intervals: yield i

when isMainModule:

  import random
  import times
  import strutils

  proc randomi(imin:int, imax:int): int =
      return imin + rand(imax - imin)

  proc brute_force(ivs: seq[Interval], start:int, stop:int, res: var seq[Interval]) =
    if res.len != 0: res.set_len(0)
    for i in ivs:
      if i.overlap(start, stop): res.add(i)

  # example implementation
  type myinterval = tuple[start:int, stop:int, val:int]
  proc start(m: myinterval): int {.inline.} = return m.start
  proc stop(m: myinterval): int {.inline.} = return m.stop

  proc make_random(n:int, range_max:int, size_min:int, size_max:int): seq[myinterval] =
    result = new_seq[myinterval](n)
    for i in 0..<n:
      var s = randomi(0, range_max)
      var e = s + randomi(size_min, size_max)
      var m:myinterval = (s, e, 0)
      result[i] = m

  var
    N = 100000
    ntimes = 40
    brute_step = 10

  var intervals = make_random(N, 50000000, 500, 20000)
  echo "running tests and comparisons on $# random intervals" % [$N]
  var icopy = intervals

  var t = cpuTime()
  var res = new_seq[myinterval]()

  for i in countup(0, intervals.len - brute_step, brute_step):
    var iv = intervals[i]
    brute_force(intervals, iv.start, iv.stop, res)

  var brute_time = cpuTime() - t
  echo "time for brute force search on 1/$#th of the data:" % [$brute_step], brute_time

  t = cpuTime()

  var lap = lapify(intervals)
  echo "time to create Lapper:", cpuTime() - t

  t = cpuTime()
  for k in 0..<ntimes:
    for iv in icopy:
      discard lap.find(iv.start, iv.stop, res)
      if len(res) == 0:
        echo "0 bad!!!"
  var lap_time = cpuTime() - t
  echo "time to do $# searches ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))

  t = cpuTime()
  for k in 0..<ntimes:
    for iv in intervals:
      discard lap.seek(iv.start, iv.stop, res)
      if len(res) == 0:
        echo "1 bad!!!"
  lap_time = cpuTime() - t
  echo "time to do $# seek-searches ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))

  var iempty: seq[myinterval]
  t = cpuTime()
  for k in 0..<ntimes:
    for iv in icopy:
      if 0 == lap.count(iv.start, iv.stop):
        echo "2 bad!!!"
  lap_time = cpuTime() - t
  echo "time to do $# presence tests ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))

  t = cpuTime()
  for k in 0..<ntimes:
    for iv in intervals:
      if not lap.seek(iv.start, iv.stop, iempty):
        echo "3 bad!!!"
  lap_time = cpuTime() - t
  echo "time to do $# seek-presence tests ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))

  t = cpuTime()
  for k in 0..<ntimes:
    for iv in intervals:
      var n = 0
      lap.each_seek(iv.start, iv.stop, (proc(f:myinterval) = (if iv.start == f.start: n.inc)))
      if n == 0:
        echo "4 bad!!!"
  lap_time = cpuTime() - t
  echo "time to do $# each-seek-presence tests ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))


  var brute_res = new_seq[myinterval]()
  var error = 0

  t = cpuTime()
  var res2 = new_seq[myinterval](10)
  var res3 = new_seq_of_cap[myinterval](10)
  var res4 = new_seq_of_cap[myinterval](10)
  proc do_each_find(m:myinterval) = res3.add(m)
  proc do_each_seek(m:myinterval) = res4.add(m)
  icopy.sort(iv_cmp)

  for iv in icopy:
    brute_force(icopy, iv.start, iv.stop, brute_res)
    discard lap.find(iv.start, iv.stop, res)
    discard lap.seek(iv.start, iv.stop, res2)

    res3.set_len(0)
    lap.each_find(iv.start, iv.stop, do_each_find)

    res4.set_len(0)
    lap.each_seek(iv.start, iv.stop, do_each_seek)

    if not lap.seek(iv.start, iv.stop, iempty):
      echo "4 bad!! should have found it"
    sort(brute_res, iv_cmp)
    sort(res, iv_cmp)
    sort(res2, iv_cmp)
    sort(res3, iv_cmp)
    sort(res4, iv_cmp)

    for i, b in brute_res:
        if b.start != res[i].start or b.start != res2[i].start or b.start != res3[i].start or b.start != res4[i].start:
          echo "5 bad!!! ", len(res), " ", len(res2)
          error = 1
        if b.stop != res[i].stop or b.stop != res2[i].stop or res3[i].stop != b.stop or res4[i].stop != b.stop:
          echo "6 bad!!! ", len(res), " ", len(res2)
          error = 1
  echo "time to check each result:", cpuTime() - t
  quit(error)
