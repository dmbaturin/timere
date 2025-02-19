include Date_time_components
include Time_ast
include Time
include Infix
module Time_zone = Time_zone

exception Invalid_format_string = Printers.Invalid_format_string

module Span = struct
  include Span

  let to_string = Printers.string_of_span

  let pp = Printers.pp_span

  let to_sexp = To_sexp.sexp_of_span

  let to_sexp_string x = CCSexp.to_string (To_sexp.sexp_of_span x)

  let of_sexp = Of_sexp.(wrap_of_sexp span_of_sexp)

  let of_sexp_string = Of_sexp.(wrap_of_sexp_into_of_sexp_string span_of_sexp)

  let pp_sexp = Printers.wrap_to_sexp_into_pp_sexp To_sexp.sexp_of_span
end

module Timestamp = struct
  let min = timestamp_min

  let max = timestamp_max

  let now = timestamp_now

  let pp = Printers.pp_timestamp

  let to_string = Printers.string_of_timestamp

  let pp_rfc3339 = RFC3339.pp_timestamp

  let pp_rfc3339_milli = RFC3339.pp_timestamp ~frac_s:3 ()

  let pp_rfc3339_micro = RFC3339.pp_timestamp ~frac_s:6 ()

  let pp_rfc3339_nano = RFC3339.pp_timestamp ~frac_s:9 ()

  let to_rfc3339 = RFC3339.of_timestamp

  let to_rfc3339_milli = RFC3339.of_timestamp ~frac_s:3

  let to_rfc3339_micro = RFC3339.of_timestamp ~frac_s:6

  let to_rfc3339_nano = RFC3339.of_timestamp ~frac_s:9

  let of_iso8601 = ISO8601.to_timestamp
end

module Date_time = struct
  include Time.Date_time'

  type tz_info = Date_time_components.tz_info

  let tz_offset_s_of_tz_info = Date_time_components.tz_offset_s_of_tz_info

  let to_string = Printers.string_of_date_time

  exception
    Date_time_cannot_deduce_tz_offset_s = Printers
                                          .Date_time_cannot_deduce_tz_offset_s

  let pp = Printers.pp_date_time

  let pp_rfc3339 = RFC3339.pp_date_time

  let pp_rfc3339_milli = RFC3339.pp_date_time ~frac_s:3 ()

  let pp_rfc3339_micro = RFC3339.pp_date_time ~frac_s:6 ()

  let pp_rfc3339_nano = RFC3339.pp_date_time ~frac_s:9 ()

  let to_rfc3339 = RFC3339.of_date_time

  let to_rfc3339_milli = RFC3339.of_date_time ~frac_s:3

  let to_rfc3339_micro = RFC3339.of_date_time ~frac_s:6

  let to_rfc3339_nano = RFC3339.of_date_time ~frac_s:9

  let of_iso8601 = ISO8601.to_date_time

  let to_sexp = To_sexp.sexp_of_date_time

  let to_sexp_string x = CCSexp.to_string (To_sexp.sexp_of_date_time x)

  let of_sexp = Of_sexp.(wrap_of_sexp date_time_of_sexp)

  let of_sexp_string =
    Of_sexp.(wrap_of_sexp_into_of_sexp_string date_time_of_sexp)

  let pp_sexp = Printers.wrap_to_sexp_into_pp_sexp To_sexp.sexp_of_date_time
end

module Interval = struct
  include Interval'

  let pp = Printers.pp_interval

  let to_string = Printers.string_of_interval
end

module Duration = struct
  include Duration

  let to_string = Printers.string_of_duration

  let pp = Printers.pp_duration

  let to_sexp = To_sexp.sexp_of_duration

  let to_sexp_string =
    To_sexp.(wrap_to_sexp_into_to_sexp_string sexp_of_duration)

  let of_sexp = Of_sexp.(wrap_of_sexp duration_of_sexp)

  let of_sexp_string =
    Of_sexp.(wrap_of_sexp_into_of_sexp_string duration_of_sexp)

  let pp_sexp = Printers.wrap_to_sexp_into_pp_sexp To_sexp.sexp_of_duration
end

type 'a range = 'a Range.range

type points = Points.t

let make_points = Points.make

let make_points_exn = Points.make_exn

let resolve = Resolver.resolve

let pp_hms = Printers.pp_hms

let string_of_hms = Printers.string_of_hms

let pp_intervals = Printers.pp_intervals

let to_sexp = To_sexp.to_sexp

let to_sexp_string = To_sexp.to_sexp_string

let of_sexp = Of_sexp.(wrap_of_sexp of_sexp)

let of_sexp_string = Of_sexp.of_sexp_string

let pp_sexp = Printers.pp_sexp

module Utils = struct
  let flatten_month_ranges (months : month range Seq.t) : month Seq.t option =
    try Some (Month_ranges.Flatten.flatten months)
    with Range.Range_is_invalid -> None

  let flatten_month_range_list (months : month range list) : month list option =
    try Some (Month_ranges.Flatten.flatten_list months)
    with Range.Range_is_invalid -> None

  let flatten_month_day_ranges (month_days : int range Seq.t) : int Seq.t option
    =
    try Some (Month_day_ranges.Flatten.flatten month_days)
    with Range.Range_is_invalid -> None

  let flatten_month_day_range_list (month_days : int range list) :
    int list option =
    try Some (Month_day_ranges.Flatten.flatten_list month_days)
    with Range.Range_is_invalid -> None

  let flatten_weekday_ranges (weekdays : weekday range Seq.t) :
    weekday Seq.t option =
    try Some (Weekday_ranges.Flatten.flatten weekdays)
    with Range.Range_is_invalid -> None

  let flatten_weekday_range_list (weekdays : weekday range list) :
    weekday list option =
    try Some (Weekday_ranges.Flatten.flatten_list weekdays)
    with Range.Range_is_invalid -> None

  let human_int_of_month = human_int_of_month

  let tm_int_of_month = tm_int_of_month

  let month_of_human_int = month_of_human_int

  let month_of_tm_int = month_of_tm_int

  let weekday_of_tm_int = weekday_of_tm_int

  let tm_int_of_weekday = tm_int_of_weekday

  let second_of_day_of_hms = second_of_day_of_hms

  let hms_of_second_of_day = hms_of_second_of_day
end
