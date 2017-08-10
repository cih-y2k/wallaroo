use "buffered"
use "collections"
use "serialise"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/fail"
use "wallaroo/state"
use "wallaroo/source"
use "wallaroo/tcp_sink"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let letter_partition = Partition[Votes val, String](
        LetterPartitionFunction, PartitionFileReader("letters.txt",
          env.root as AmbientAuth))

      let letter_partition2 = Partition[LetterTotal val, String](
        LetterPartitionFunction2, PartitionFileReader("letters.txt",
          env.root as AmbientAuth))

      let application = recover val
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            TCPSourceConfig[Votes val].from_options(VotesDecoder,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_state_partition[LetterTotal val, String, LetterTotal val,
              LetterState](AddVotes2, LetterStateBuilder, "letter-state-2",
              letter_partition2 where multi_worker = true)
            .to_state_partition[LetterTotal val, String, LetterTotal val,
              LetterState](AddVotes2, LetterStateBuilder, "letter-state-3",
              letter_partition2 where multi_worker = true)
            .to_state_partition[LetterTotal val, String, LetterTotal val,
              LetterState](AddVotes2, LetterStateBuilder, "letter-state-4",
              letter_partition2 where multi_worker = true)
            .to_state_partition[LetterTotal val, String, LetterTotal val,
              LetterState](AddVotes2, LetterStateBuilder, "letter-state-5",
              letter_partition2 where multi_worker = true)
            .to_sink(TCPSinkConfig[LetterTotal val].from_options(LetterTotalEncoder,
              TCPSinkConfigCLIParser(env.args)(0)))
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes X",
            TCPSourceConfig[Votes val].from_options(VotesDecoder,
              TCPSourceConfigCLIParser(env.args)(0)))
            .to[Votes val](VotesIdentityBuilder)
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state-x",
              letter_partition where multi_worker = true)
            .to_state_partition[LetterTotal val, String, LetterTotal val,
              LetterState](AddVotes2, LetterStateBuilder, "letter-state-y",
              letter_partition2 where multi_worker = true)
            .to_sink(TCPSinkConfig[LetterTotal val].from_options(LetterTotalEncoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application, "alphabet-contest")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val VotesIdentity
  fun apply(v: Votes val): Votes val =>
    v

  fun name(): String =>
    "VotesIdentity"

class val VotesIdentityBuilder
  fun apply(): VotesIdentity =>
    VotesIdentity

class val LetterStateBuilder
  fun apply(): LetterState => LetterState
  fun name(): String => "Letter State"

class LetterState is State
  var letter: String = " "
  var count: U32 = 0

class AddVotesStateChange is StateChange[LetterState]
  var _id: U64
  var _votes: Votes val = Votes(" ", 0)

  new create(id': U64) =>
    _id = id'

  fun name(): String => "AddVotes"
  fun id(): U64 => _id

  fun ref update(votes': Votes val) =>
    _votes = votes'

  fun apply(state: LetterState ref) =>
    state.letter = _votes.letter
    state.count = state.count + _votes.count

  fun write_log_entry(out_writer: Writer) =>
    out_writer.u32_be(_votes.letter.size().u32())
    out_writer.write(_votes.letter)
    out_writer.u32_be(_votes.count)

  fun ref read_log_entry(in_reader: Reader) ? =>
    let letter_size = in_reader.u32_be().usize()
    let letter = String.from_array(in_reader.block(letter_size))
    let count = in_reader.u32_be()
    _votes = Votes(letter, count)

class AddVotesStateChangeBuilder is StateChangeBuilder[LetterState]
  fun apply(id: U64): StateChange[LetterState] =>
    AddVotesStateChange(id)

primitive AddVotes is StateComputation[Votes val, LetterTotal val, LetterState]
  fun name(): String => "Add Votes"

  fun apply(votes: Votes val,
    sc_repo: StateChangeRepository[LetterState],
    state: LetterState): (LetterTotal val, StateChange[LetterState] ref)
  =>
    let state_change: AddVotesStateChange ref =
      try
        sc_repo.lookup_by_name("AddVotes") as AddVotesStateChange
      else
        AddVotesStateChange(0)
      end

    state_change.update(votes)

    (LetterTotal(votes.letter, state.count + votes.count), state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[LetterState] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[LetterState] val]
      scbs.push(recover val AddVotesStateChangeBuilder end)
    end

primitive AddVotes2 is StateComputation[LetterTotal val, LetterTotal val,
  LetterState]
  fun name(): String => "Add Votes 2"

  fun apply(lt: LetterTotal val,
    sc_repo: StateChangeRepository[LetterState],
    state: LetterState): (LetterTotal val, StateChange[LetterState] ref)
  =>
    let state_change: AddVotesStateChange ref =
      try
        sc_repo.lookup_by_name("AddVotes") as AddVotesStateChange
      else
        AddVotesStateChange(0)
      end

    state_change.update(Votes(lt.letter, lt.count))

    (LetterTotal(lt.letter, state.count + lt.count), state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[LetterState] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[LetterState] val]
      scbs.push(recover val AddVotesStateChangeBuilder end)
    end

primitive VotesDecoder is FramedSourceHandler[Votes val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    5

  fun decode(data: Array[U8] val): Votes val ? =>
    // Assumption: 1 byte for letter
    let letter = String.from_array(data.trim(0, 1))
    let count = Bytes.to_u32(data(1), data(2), data(3), data(4))
    Votes(letter, count)

primitive LetterPartitionFunction
  fun apply(votes: Votes val): String =>
    votes.letter

primitive LetterPartitionFunction2
  fun apply(votes: LetterTotal val): String =>
    votes.letter

class Votes
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c

class LetterTotal
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c

primitive LetterTotalEncoder
  fun apply(t: LetterTotal val, wb: Writer = Writer): Array[ByteSeq] val =>
    @printf[I32]("%s, %s\n".cstring(), t.letter.cstring(),
      t.count.string().cstring())
    wb.write(t.letter) // Assumption: letter is 1 byte
    wb.u32_be(t.count)
    wb.done()