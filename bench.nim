import lapper
import algorithm
import math
import strutils
import random
import times

#type myinterval = tuple[start:int, stop:int]
#proc start(m: myinterval): int {.inline.} = return m.start
#proc stop(m: myinterval): int {.inline.} = return m.stop

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

proc randomi(imin:int, imax:int): int =
  return imin + random(imax - imin)

proc brute_force(ivs: seq[Interval], start:int, stop:int, res: var seq[Interval]) =
  if res.len != 0: res.set_len(0)
  for i in ivs:
    if i.start <= stop and i.stop >= start: res.add(i)

proc make_random(n:int, range_max:int, size_min:int, size_max:int): seq[myinterval] =
  result = new_seq[myinterval](n)
  for i in 0..<n:
    var s = randomi(0, range_max)
    var e = s + randomi(size_min, size_max)
    var m:myinterval = myinterval(start:s, stop:e, val: 0)
    result[i] = m


var n_intervals = 200000
var range_max = 50000000 # 50M
var res = new_seq[myinterval](100)

echo "# generating and searching $#K random intervals in the domain of 0..$#M" % [$(n_intervals / 1000).int, $(range_max / 1000000).int]
echo "| max interval size | brute-force time | lapper time | lapper seek time | speedup | seek speedup | each_seek speedup |"
echo "| ----------------- | ---------------- | ----------- | ---------------  | ------- | ------------ | ----------------- |"
proc doit(m:myinterval) =
  discard m

for max_length_pow in @[1, 2, 3, 4, 5, 6, 7]:
    var size_max = pow(10'f64, max_length_pow.float64)
    var size_min = size_max / 3

    var ivs = make_random(n_intervals, range_max, size_min.int, size_max.int)
    ivs.sort(proc(a, b: myinterval): int =
      if a.start == b.start:
        return a.stop - b.stop
      else:
        return a.start - b.start)
    var icopy = ivs

    var t = cpuTime()
    for itry in 0..10:
      var l = lapify(ivs)
      for iv in icopy:
        discard l.find(iv.start, iv.stop, res)
        if len(res) == 0:
            stderr.write_line "WTF!!!"
            quit(2)
    var lap_time = (cpuTime() - t)/10

    t = cpuTime()
    for itry in 0..10:
      var l = lapify(ivs)
      for iv in ivs:
        discard l.seek(iv.start, iv.stop, res)
        if len(res) == 0:
            stderr.write_line "WTF!!!"
            quit(2)
    var lap_seek_time = (cpuTime() - t)/10

    t = cpuTime()
    for itry in 0..10:
      var l = lapify(ivs)
      for iv in ivs:
        l.each_seek(iv.start, iv.stop, doit)
    var lap_seek_do_time = (cpuTime() - t) / 10

    t = cpuTime()
    var brute_step = 10000
    # brute force is too slow so do 1/10th of intervals then multiply time
    for i in countup(0, icopy.high, brute_step):
      var iv = icopy[i]
      brute_force(icopy, iv.start, iv.stop, res)
      if len(res) == 0:
          stderr.write_line "brute WTF!!!"
          quit(2)
    var brute_time = brute_step.float64 * (cpuTime() - t)

    var speed_up = brute_time / lap_time
    var seek_speed_up = brute_time / lap_seek_time
    var seek_do_speed_up = brute_time / lap_seek_do_time

    proc f(v:float64, precision:int=2): string =
      return formatFloat(v, ffDecimal, precision=precision)

    echo "|", pow(10'f64, max_length_pow.float64).int, "|", f(brute_time), "|", f(lap_time, 3), "|", f(lap_seek_time, 3), "|", f(speed_up) , "|", f(seek_speed_up), "|", f(seek_do_speed_up), "|"
