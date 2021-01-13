type timestamp = int64

type unary_op =
  | Not
  | Drop_points of int
  | Take_points of int
  | Shift of int64
  | Lengthen of int64
  | With_tz of Time_zone.t

type chunking =
  [ `Disjoint_intervals
  | `By_duration of Duration.t
  | `By_duration_drop_partial of Duration.t
  | `At_year_boundary
  | `At_month_boundary
  ]

type chunked_unary_op_on_t =
  | Chunk_disjoint_interval
  | Chunk_at_year_boundary
  | Chunk_at_month_boundary
  | Chunk_by_duration of {
      chunk_size : int64;
      drop_partial : bool;
    }

type chunked_unary_op_on_chunked =
  | Drop of int
  | Take of int
  | Take_nth of int
  | Nth of int
  | Chunk_again of chunked_unary_op_on_t

type t =
  | Empty
  | All
  | Pattern of Pattern.t
  | Point of timestamp
  | Interval_inc of int64 * t * t
  | Interval_exc of int64 * t * t
  | Unary_op of unary_op * t
  | Round_robin_pick_list of t list
  | Inter_seq of t Seq.t
  | Union_seq of t Seq.t
  | Follow of int64 * t * t
  | Unchunk of chunked

and chunked =
  | Unary_op_on_t of chunked_unary_op_on_t * t
  | Unary_op_on_chunked of chunked_unary_op_on_chunked * chunked
