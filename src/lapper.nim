## This module provides a simple data-structure for fast interval searches.
## It does not use an interval tree, instead, it operates on the assumption that
## most intervals are of similar length; or, more exactly, that the longest interval
## in the set is not long compared to the average distance between intervals. On
## any dataset where that is not the case, this method will not perform well.
## For cases where this holds true (as it often does with genomic data), we can
## sort by start and use binary search on the starts, accounting for the length
## of the longest interval. The advantage of this approach is simplicity of implementation
## and speed. In realistic tests queries returning the overlapping intervals are
## 500 times faster than brute force and queries that merely check for the overlaps
## are > 2500 times faster.
import algorithm

type

  Interval* = concept i
    ## An object/tuple must implement these 2 methods to use this module
    start(i) is int
    stop(i) is int

  Lapper*[T] = object
    ## Lapper enables fast interval searches
    intervals: seq[T]
    max_len: int

proc iv_cmp[T:Interval](a, b: T): int =
    if a.start < b.start: return -1
    if b.start < a.start: return 1
    return cmp(a.stop, b.stop)

proc lapify*[T:Interval](ivs:var seq[T]): Lapper[T] =
  ## create a new Lapper object
  sort(ivs, iv_cmp)
  var l = Lapper[T](max_len: 0, intervals:ivs)
  for iv in ivs:
    if iv.stop - iv.start > l.max_len:
      l.max_len = iv.stop - iv.start
  return l

proc lowerBound[T:Interval](a: seq[T], start: int): int =
  result = a.low
  var count = a.high - a.low + 1
  var step, pos: int
  while count != 0:
    step = count div 2
    pos = result + step
    if cmp(a[pos].start, start) < 0:
      result = pos + 1
      count -= step + 1
    else:
      count = step

proc find*[T:Interval](L:Lapper[T], start:int, stop:int, ivs:var seq[T]) =
  if ivs.len != 0: ivs.set_len(0)
  var off = lowerBound(L.intervals, start - L.max_len)
  for i in off..L.intervals.high:
    var x = L.intervals[i]
    if x.start <= stop and x.stop >= start: ivs.add(x)
    elif x.start > (stop + L.max_len): break

proc overlaps*[T:Interval](L:Lapper[T], start:int, stop:int): bool =
  var off = lowerBound(L.intervals, start - L.max_len)
  for i in off..L.intervals.high:
    var x = L.intervals[i]
    if x.start <= stop and x.stop >= start: return true
    elif x.start > (stop + L.max_len): break
  return false

when isMainModule:

  import random
  import times
  import strutils

  proc randomi(imin:int, imax:int): int =
      return imin + random(imax - imin)

  proc brute_force(ivs: seq[Interval], start:int, stop:int, res: var seq[Interval]) =
    if res.len != 0: res.set_len(0)
    for i in ivs:
      if i.start <= stop and i.stop >= start: res.add(i)

  ## example implementation
  type myinterval = tuple[start:int, stop:int]
  proc start(m: myinterval): int {.inline.} = return m.start
  proc stop(m: myinterval): int {.inline.} = return m.stop

  proc make_random(n:int, range_max:int, size_min:int, size_max:int): seq[myinterval] =
    result = new_seq[myinterval](n)
    for i in 0..<n:
      var s = randomi(0, range_max)
      var e = s + randomi(size_min, size_max)
      var m:myinterval = (s, e)
      result[i] = m

  var
    N = 200000
    ntimes = 100
    brute_step = 10

  var intervals = make_random(N, 50000000, 500, 20000)
  echo "running tests and comparisons on $# random intervals" % [$N]
  var icopy = intervals

  var t = cpuTime()
  var res = new_seq[myinterval]()

  for i in countup(0, intervals.len, brute_step):
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
      lap.find(iv.start, iv.stop, res)
      if len(res) == 0:
        echo "bad!!!"
  var lap_time = cpuTime() - t
  echo "time to do $# searches ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))

  t = cpuTime()
  for k in 0..<ntimes:
    for iv in icopy:
      if not lap.overlaps(iv.start, iv.stop):
        echo "bad!!!"
  lap_time = cpuTime() - t
  echo "time to do $# presence tests ($# reps) in Lapper:" % [$(N * ntimes), $ntimes], lap_time, " speedup:", (brute_time * float64(brute_step)) / (lap_time / float64(ntimes))

  var brute_res = new_seq[myinterval]()
  var error = 0

  t = cpuTime()
  for iv in icopy:
    brute_force(icopy, iv.start, iv.stop, brute_res)
    lap.find(iv.start, iv.stop, res)
    sort(brute_res, iv_cmp)
    sort(res, iv_cmp)
    for i, b in brute_res:
        if b.start != res[i].start:
          echo "bad!!!"
          error = 1
        if b.stop != res[i].stop:
          echo "bad!!!"
          error = 1
  echo "time to check each result:", cpuTime() - t
  quit(error)
