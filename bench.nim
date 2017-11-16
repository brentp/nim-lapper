import lapper
import math
import strutils
import random
import times

type myinterval = tuple[start:int, stop:int]
proc start(m: myinterval): int {.inline.} = return m.start
proc stop(m: myinterval): int {.inline.} = return m.stop


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
    var m:myinterval = (s, e)
    result[i] = m


var n_intervals = 100000
var range_max = 50000000 # 50M
var res = new_seq[myinterval](100)

echo "# generating and searching $#K random intervals in the domain of 0..$#M" % [$(n_intervals / 1000).int, $(range_max / 1000000).int]
echo "| max interval size | lapper time | brute-force time | speedup |"
echo "| ----------------- | ----------- | ---------------  | ------- |"

for max_length_pow in @[1, 2, 3, 4, 5, 6, 7]:
    var size_max = pow(10'f64, max_length_pow.float64)
    var size_min = size_max / 3

    var ivs = make_random(n_intervals, range_max, size_min.int, size_max.int)
    var icopy = ivs

    var t = cpuTime()
    var l = lapify(ivs)
    for iv in icopy:
      l.find(iv.start, iv.stop, res)
      if len(res) == 0:
          stderr.write_line "WTF!!!"
          quit(2)
    var lap_time = cpuTime() - t

    t = cpuTime()
    # brute force is too slow so do 1/10th of intervals then multiply time
    var brute_step = 10
    for i in countup(0, icopy.high, brute_step):
      var iv = icopy[i]
      brute_force(icopy, iv.start, iv.stop, res)
      if len(res) == 0:
          stderr.write_line "brute WTF!!!"
          quit(2)
    var brute_time = brute_step.float64 * (cpuTime() - t)
    var speed_up = brute_time / lap_time

    echo "|", pow(10'f64, max_length_pow.float64).int, "|", lap_time, "|", brute_time, "|", speed_up , "|"
