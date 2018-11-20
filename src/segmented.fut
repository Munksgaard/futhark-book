-- | Irregular segmented operations, like scans and reductions.

-- | Segmented scan. Given a binary associative operator ``op`` with
-- neutral element ``ne``, computes the inclusive prefix scan of the
-- segments of ``as`` specified by the ``flags`` array, where `true`
-- starts a segment and `false` continues a segment.
let segmented_scan [n] 't (op: t -> t -> t) (ne: t)
                          (flags: [n]bool) (as: [n]t): [n]t =
  (unzip (scan (\(x_flag,x) (y_flag,y) ->
                (x_flag || y_flag,
                 if y_flag then y else x `op` y))
          (false, ne)
          (zip flags as))).2

-- | Segmented reduction. Given a binary associative operator ``op``
-- with neutral element ``ne``, computes the reduction of the segments
-- of ``as`` specified by the ``flags`` array, where `true` starts a
-- segment and `false` continues a segment.  One value is returned per
-- segment.
let segmented_reduce [n] 't (op: t -> t -> t) (ne: t)
                            (flags: [n]bool) (as: [n]t) =
  -- Compute segmented scan.  Then we just have to fish out the end of
  -- each segment.
  let as' = segmented_scan op ne flags as
  -- Find the segment ends.
  let segment_ends = rotate 1 flags
  -- Find the offset for each segment end.
  let segment_end_offsets = segment_ends |> map i32.bool |> scan (+) 0
  let num_segments = if n > 1 then segment_end_offsets[n-1] else 0
  -- Make room for the final result.  The specific value we write here
  -- does not matter; they will all be overwritten by the segment
  -- ends.
  let scratch = replicate num_segments ne
  -- Compute where to write each element of as'.  Only segment ends
  -- are written.
  let index i f = if f then i-1 else -1
  in scatter scratch (map2 index segment_end_offsets segment_ends) as'

-- | Replicated iota. Given a repetition array, the function returns
-- an array with each index (starting from 0) repeated according to
-- the repetition array. As an example, replicated_iota [2,3,1]
-- returns the array [0,0,1,1,1,2].

let replicated_iota [n] (reps:[n]i32) : []i32 =
  let s1 = scan (+) 0 reps
  let s2 = map (\i -> if i==0 then 0 else unsafe s1[i-1]) (iota n)
  let tmp = scatter (replicate (reduce (+) 0 reps) 0) s2 (iota n)
  let flags = map (>0) tmp
  in segmented_scan (+) 0 flags tmp

-- | Segmented iota. Given a flags array, the function returns an
-- array of index sequences, each of which is reset according to the
-- flags array. As an examples, segmented_iota
-- [false,false,false,true,false,false,false] returns the array
-- [0,1,2,0,1,2,3].

let segmented_iota [n] (flags:[n]bool) : [n]i32 =
  let iotas = segmented_scan (+) 0 flags (replicate n 1)
  in map (\x -> x-1) iotas

-- | Generic expansion function. The function expands a source array
-- into a target array given (1) a function that determines, for each
-- source element, how many target elements it expands to and (2) a
-- function that computes a particular target element based on a
-- source element and the target element number associated with the
-- source. As an example, the expression expand (\x->x) (*) [2,3,1]
-- returns the array [0,2,0,3,6,0].

let expand 'a 'b (sz: a -> i32) (get: a -> i32 -> b) (arr:[]a) : []b =
  let szs = map sz arr
  let idxs = replicated_iota szs
  let iotas = segmented_iota (map2 (!=) idxs (rotate (i32.negate 1) idxs))
  in map2 (\i j -> unsafe get arr[i] j) idxs iotas
