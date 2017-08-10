"""
Functionality that has to do with encoding and decoding anything goes in here
so that it may be unit tested separately from the main application.
"""


use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/source"
use "wallaroo/tcp_source"

primitive WindowEncoder
  fun apply(s: String val, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef debug then
      @printf[I32]("output: %s\n".cstring(), s.cstring())
    end
    wb.writev(Bytes.length_encode(s))
    wb.done()

primitive WindowU64Decoder
  """
  Decode a text array of numbers in the format '[1,2,3]' or '[1, 2, 3]'
  into an Array[U64].
  """
  fun apply(s: String val, delim: String val = "[, ]"): Array[U64] val ? =>
    let a = recover iso Array[U64] end
    let parts:Array[String] val = s.split(delim)
    for p in parts.slice(1,parts.size()-1).values() do
      // skip empty strings
      if p.size() > 0 then
        a.push(p.u64())
      end
    end
    consume a

primitive WindowStateEncoder
  fun apply(index: USize, buf: Array[U64], size: USize,
    count: USize, out_writer: Writer)
  =>
    out_writer.u64_be(index.u64())
    // This is relying on the array being initialized with zeroes
    for v in buf.values() do
      out_writer.u64_be(v)
    end
    out_writer.u64_be(size.u64())
    out_writer.u64_be(count.u64())

primitive WindowStateDecoder
  fun apply(in_reader: Reader): (USize, Array[U64] iso^, USize, USize) ?
  =>
    let index = in_reader.u64_be().usize()
    let a: Array[U64] iso = recover Array[U64 val] end
    for x in Range[USize](0,4) do
      a.push(in_reader.u64_be())
    end
    let size = in_reader.u64_be().usize()
    let count = in_reader.u64_be().usize()
    (index, consume a, size, count)

primitive U64FramedHandler is FramedSourceHandler[U64 val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0), data(1), data(2), data(3),
      data(4), data(5), data(6), data(7))