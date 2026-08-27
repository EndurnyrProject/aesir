defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScript do
  @moduledoc """
  Owner of the `on_equip` bonus-program format: the single place where the
  input-pure program produced by `EquipCodegen` is defined, serialized,
  deserialized, and evaluated.

  A program is plain data (a list of tuples). It is stored in `equip.yml` as an
  Elixir DSL source string in the same style as `on_use` (`to_source/1`), e.g.
  `bonus(ctx, :int, 3)` or

      ctx = bonus(ctx, :vit, 5)
      ctx = bonus(ctx, :def, 10)
      ctx

  and parsed back to the tuple form at load time through a closed vocabulary
  (`parse!/1`): `bonus/3`, `refine/1`, `base_level/1`, `job_level/1`,
  `+ - *`, `div/2`, `min/2`, `max/2`, `pow/2`, comparisons, `&&`/`||`,
  `job_is/3`, `job_is_not/3`, `bool/2`, `if/else` statements, and the
  inline `if(cond, do: a, else: b)` ternary expression. Unlike `on_use` the
  source is never compiled to code — the equip corpus (~13k items) is far past
  the BEAM clause-count ceiling — so `eval/2` interprets the tuple program
  against the `t:inputs/0` map during the stats recompute. The evaluator is
  pure and deterministic in `(program, inputs)` — the three inputs (the item's
  refine, the wearer's base and job level) are the only reads the vocabulary
  admits, and there is no randomness. Level inputs change on level-up, which is
  why the stats recompute re-evaluates programs (`Stats.apply_equipment_modifiers`
  caches `worn_items` for exactly that refold).

  Corrupt stored data must fail loudly rather than silently degrade: `parse!/1`
  raises on any construct outside the vocabulary, any unknown bonus
  destination, or malformed shape.

  ## Skill-aware constructs

  Two constructs read/grant player skills rather than folding a stat:

  - `{:skill_lv, id}` (source `skill_lv(ctx, id)`) is an expression that reads
    the wearer's learned level of skill `id`, `0` when unlearned. It consults
    the optional `:learned_skills` input; an item that never uses it needs no
    such input.
  - `{:grant_skill, id, expr}` (source `grant_skill(ctx, id, expr)`) grants the
    wearer a castable skill at the evaluated level while the item is worn. It
    folds into a reserved `{:granted_skill, id}` accumulator key with `max`
    semantics (the strongest grant wins, both within one program and — via the
    `Stats` cross-item merge — across worn items); `Stats` partitions those keys
    out of the numeric bonus map into its own granted-skills channel.

  ## Stat-aware constructs

  `{:stat, atom}` (source `stat(ctx, :str)`) is an expression that reads one of
  the wearer's character stats (`readparam(bStr)` in the corpus). It consults
  the optional `:stats` input, a `%{stat_atom => integer}` map of the wearer's
  base stats (allocated points plus job bonuses, excluding this equipment's own
  contribution so the read is non-circular); a stat the map lacks reads `0`. The
  supported atoms are the six base stats (`:str :agi :vit :int :dex :luk`) and
  the six trait stats (`:pow :sta :wis :spl :con :crt`).

  ## Job-aware constructs

  Two constructs gate on the wearer's job, reading the optional `:job_id` input
  (an absent input reads as job `0`, Novice):

  - `{:job_cmp, op, reader, job}` is a condition comparing a job reader against a
    job atom (`op` is `:==` or `:!=`). `reader` is `:class` (the current job),
    `:base_class` (the first-job lineage root, rAthena `BaseClass`) or
    `:base_job` (the trans/baby-collapsed job, rAthena `BaseJob`), computed via
    `JobLineage`. Source forms: `job_is(ctx, :base_class, :swordman)` and
    `job_is_not(ctx, :class, :soul_linker)`.
  - `{:bool, condition}` (source `bool(ctx, <cond>)`) is an expression yielding
    `1` when the condition holds and `0` otherwise - rAthena's C idiom of using
    a comparison as an integer term, e.g. `bonus bDef,2+3*(getrefine()>5)`.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.Skill.Learned

  @type arith_op :: :+ | :- | :* | :div | :min | :max | :pow
  @type compare_op :: :> | :< | :>= | :<= | :== | :!=
  @type logic_op :: :and | :or

  @typedoc "A wearer job reader: current job, first-job lineage, or trans/baby-collapsed job."
  @type job_reader :: :class | :base_class | :base_job

  @typedoc """
  The evaluation inputs: the item's refine and the wearer's levels, plus the
  optional wearer learned-skills map read by `{:skill_lv, id}` expressions.
  """
  @type inputs :: %{
          :refine => integer(),
          :base_level => integer(),
          :job_level => integer(),
          optional(:learned_skills) => %{integer() => non_neg_integer()},
          optional(:stats) => %{atom() => integer()},
          optional(:job_id) => integer()
        }

  @typedoc """
  An input-pure arithmetic expression evaluating to an integer. `{:ternary, c, a, b}`
  is the rAthena `c ? a : b` conditional expression: `a` when the condition
  holds, `b` otherwise. Besides `+ - * div`, the binary-op form also carries the
  two-argument math combinators `min`, `max` and `pow` (integer exponentiation;
  a negative exponent yields `0`, matching the C-cast-to-int semantics).
  """
  @type expr ::
          integer()
          | :refine
          | :base_level
          | :job_level
          | {arith_op(), expr(), expr()}
          | {:ternary, condition(), expr(), expr()}
          | {:skill_lv, pos_integer()}
          | {:stat, atom()}
          | {:bool, condition()}

  @typedoc "An input-pure boolean condition gating an `:if` instruction or a ternary."
  @type condition ::
          {compare_op(), expr(), expr()}
          | {logic_op(), condition(), condition()}
          | {:job_cmp, :== | :!=, job_reader(), atom()}

  @typedoc """
  A bonus destination: a flat atom for section-3 keys, or a `{family, param}`
  tuple for parameterized `bonus2` keys — `param` is an atom drawn from the
  family's `BonusKeys` domain (race/element/size/class/race2), a positive
  integer skill or item id, or a positive-integer interval in milliseconds for
  the periodic HP-regen/loss families. A key written with a trigger-condition
  flag (`bonus3 bSubEle,Ele_Fire,3,BF_MAGIC`) widens its param to a
  `{param, flag}` pair, so the bonus applies only to attacks the flag matches.
  The race-gated monster-drop bonus (`bonus3 bAddMonsterDropItem,iid,r,n`) uses
  a three-element `{family, item_id, race}` tuple.
  """
  @type param :: atom() | pos_integer()
  @type dest ::
          atom()
          | {atom(), param() | {param(), non_neg_integer()}}
          | {atom(), pos_integer(), atom()}

  @typedoc """
  A constant-valued destination assignment, for the `bonus` keys whose argument
  is a constant rather than an amount (`bonus bAtkEle,Ele_Fire;`). Unlike
  `:bonus` these do not sum — the last one evaluated wins.
  """
  @type value :: atom()

  @typedoc """
  The constant half of an autocast bonus: which trigger arms it, the skill it
  casts, the attack kinds that fire it, and the force bits deciding target and
  level randomization. The level and chance are expressions, so they ride the
  instruction rather than this map.
  """
  @type auto_cast_spec :: %{
          trigger: :attack | :when_hit,
          skill_id: pos_integer(),
          flag: non_neg_integer(),
          force: non_neg_integer()
        }

  @typedoc "A single bonus program statement."
  @type instr ::
          {:bonus, dest(), expr()}
          | {:set, dest(), value()}
          | {:grant_skill, pos_integer(), expr()}
          | {:auto_cast, auto_cast_spec(), expr(), expr()}
          | {:if, condition(), [instr()], [instr()]}

  @typedoc "A bonus program: an ordered list of instructions."
  @type program :: [instr()]

  @compare_ops [:>, :<, :>=, :<=, :==, :!=]
  @plain_arith_ops [:+, :-, :*]

  # The stat atoms a `{:stat, atom}` expression may read: the six base stats and
  # six trait stats, matching `Resolver.stat_params/0`'s value set.
  @stat_params [:str, :agi, :vit, :int, :dex, :luk, :pow, :sta, :wis, :spl, :con, :crt]

  @doc """
  Renders a program as an Elixir DSL source string, mirroring the `on_use`
  ctx-threading conventions: a single instruction is the bare call, multiple
  instructions rebind `ctx` line by line and return it, and `if` branches each
  evaluate to `ctx`.
  """
  @spec to_source(program()) :: String.t()
  def to_source(program) when is_list(program), do: render_stmts(program)

  @doc """
  Strictly parses a DSL source string back to the tuple program form.

  The source is read with `Code.string_to_quoted!/1` and walked against a
  closed vocabulary; flat bonus destinations are validated through
  `BonusKeys.destinations/0`, and `{family, param}` tuple destinations through
  `BonusKeys.families/0` and `BonusKeys.family_param/1` (atom params against
  the family's domain, skill params as positive integers). Any unknown call,
  operator, destination, or malformed shape raises `ArgumentError` — corrupt
  data must not load silently.
  """
  @spec parse!(String.t()) :: program()
  def parse!(source) when is_binary(source) do
    source |> Code.string_to_quoted!() |> parse_stmts()
  end

  @doc """
  Evaluates a program against its `t:inputs/0`, folding every `:bonus` into a
  `%{destination => integer}` accumulator. `:set` instructions store their
  constant instead, overwriting rather than summing, and the non-stackable
  destinations (`BonusKeys.max_destination?/1`) keep the largest contribution
  instead of summing. Pure and deterministic in `(program, inputs)`; an input
  the program reads but the map lacks raises.
  """
  @spec eval(program(), inputs()) :: %{dest() => integer() | value()}
  def eval(program, inputs) when is_list(program) and is_map(inputs) do
    eval_instrs(program, inputs, %{})
  end

  defp render_stmts([]), do: "ctx"
  defp render_stmts([instr]), do: render_instr(instr)

  defp render_stmts(instrs) do
    instrs
    |> Enum.map(&"ctx = #{render_instr(&1)}")
    |> Kernel.++(["ctx"])
    |> Enum.join("\n")
  end

  defp render_instr({:bonus, dest, expr}) do
    "bonus(ctx, #{inspect(dest)}, #{render_expr(expr)})"
  end

  defp render_instr({:set, dest, value}) do
    "set(ctx, #{inspect(dest)}, #{inspect(value)})"
  end

  defp render_instr({:grant_skill, id, expr}) do
    "grant_skill(ctx, #{id}, #{render_expr(expr)})"
  end

  defp render_instr({:auto_cast, spec, level, rate}) do
    "auto_cast(ctx, #{inspect(spec)}, #{render_expr(level)}, #{render_expr(rate)})"
  end

  defp render_instr({:if, condition, then_branch, else_branch}) do
    "if #{render_cond(condition)} do\n" <>
      "#{indent(render_stmts(then_branch))}\nelse\n#{indent(render_stmts(else_branch))}\nend"
  end

  defp render_expr(int) when is_integer(int), do: Integer.to_string(int)
  defp render_expr(:refine), do: "refine(ctx)"
  defp render_expr(:base_level), do: "base_level(ctx)"
  defp render_expr(:job_level), do: "job_level(ctx)"
  defp render_expr({:skill_lv, id}), do: "skill_lv(ctx, #{id})"
  defp render_expr({:stat, stat}), do: "stat(ctx, #{inspect(stat)})"
  defp render_expr({:bool, condition}), do: "bool(ctx, #{render_cond(condition)})"
  defp render_expr({:div, l, r}), do: "div(#{render_expr(l)}, #{render_expr(r)})"
  defp render_expr({:min, l, r}), do: "min(#{render_expr(l)}, #{render_expr(r)})"
  defp render_expr({:max, l, r}), do: "max(#{render_expr(l)}, #{render_expr(r)})"
  defp render_expr({:pow, l, r}), do: "pow(#{render_expr(l)}, #{render_expr(r)})"

  defp render_expr({:ternary, condition, then_expr, else_expr}) do
    "if(#{render_cond(condition)}, do: #{render_expr(then_expr)}, else: #{render_expr(else_expr)})"
  end

  defp render_expr({op, l, r}) when op in @plain_arith_ops do
    "(#{render_expr(l)} #{op} #{render_expr(r)})"
  end

  defp render_cond({op, l, r}) when op in @compare_ops do
    "(#{render_expr(l)} #{op} #{render_expr(r)})"
  end

  defp render_cond({:and, l, r}), do: "(#{render_cond(l)} && #{render_cond(r)})"
  defp render_cond({:or, l, r}), do: "(#{render_cond(l)} || #{render_cond(r)})"

  defp render_cond({:job_cmp, :==, reader, job}),
    do: "job_is(ctx, #{inspect(reader)}, #{inspect(job)})"

  defp render_cond({:job_cmp, :!=, reader, job}),
    do: "job_is_not(ctx, #{inspect(reader)}, #{inspect(job)})"

  defp indent(source) do
    source
    |> String.split("\n")
    |> Enum.map_join("\n", &"  #{&1}")
  end

  defp parse_stmts({:__block__, _, stmts}), do: Enum.flat_map(stmts, &parse_stmt/1)
  defp parse_stmts(single), do: parse_stmt(single)

  defp parse_stmt({:=, _, [{:ctx, _, c}, rhs]}) when is_atom(c), do: parse_stmt(rhs)
  defp parse_stmt({:ctx, _, c}) when is_atom(c), do: []
  defp parse_stmt(quoted), do: [parse_instr!(quoted)]

  defp parse_instr!({:bonus, _, [{:ctx, _, c}, dest, expr]}) when is_atom(c) do
    {:bonus, validate_destination!(dest), parse_expr!(expr)}
  end

  defp parse_instr!({:set, _, [{:ctx, _, c}, dest, value]}) when is_atom(c) do
    validate_value!(dest, value)
  end

  defp parse_instr!({:grant_skill, _, [{:ctx, _, c}, id, expr]}) when is_atom(c) do
    {:grant_skill, validate_skill_id!(id), parse_expr!(expr)}
  end

  defp parse_instr!({:auto_cast, _, [{:ctx, _, c}, spec, level, rate]}) when is_atom(c) do
    {:auto_cast, validate_auto_cast_spec!(spec), parse_expr!(level), parse_expr!(rate)}
  end

  defp parse_instr!({:if, _, [condition, [do: then_q, else: else_q]]}) do
    {:if, parse_cond!(condition), parse_stmts(then_q), parse_stmts(else_q)}
  end

  defp parse_instr!({:if, _, [condition, [do: then_q]]}) do
    {:if, parse_cond!(condition), parse_stmts(then_q), []}
  end

  defp parse_instr!(other), do: malformed!("instruction", other)

  defp parse_expr!(int) when is_integer(int), do: int
  defp parse_expr!({:-, _, [int]}) when is_integer(int), do: -int
  defp parse_expr!({:refine, _, [{:ctx, _, c}]}) when is_atom(c), do: :refine
  defp parse_expr!({:base_level, _, [{:ctx, _, c}]}) when is_atom(c), do: :base_level
  defp parse_expr!({:job_level, _, [{:ctx, _, c}]}) when is_atom(c), do: :job_level

  defp parse_expr!({:skill_lv, _, [{:ctx, _, c}, id]}) when is_atom(c),
    do: {:skill_lv, validate_skill_id!(id)}

  defp parse_expr!({:stat, _, [{:ctx, _, c}, stat]}) when is_atom(c),
    do: {:stat, validate_stat!(stat)}

  defp parse_expr!({:bool, _, [{:ctx, _, c}, condition]}) when is_atom(c),
    do: {:bool, parse_cond!(condition)}

  defp parse_expr!({op, _, [l, r]}) when op in [:+, :-, :*, :div, :min, :max, :pow] do
    {op, parse_expr!(l), parse_expr!(r)}
  end

  defp parse_expr!({:if, _, [condition, [do: then_q, else: else_q]]}) do
    {:ternary, parse_cond!(condition), parse_expr!(then_q), parse_expr!(else_q)}
  end

  defp parse_expr!(other), do: malformed!("expression", other)

  defp parse_cond!({op, _, [l, r]}) when op in @compare_ops do
    {op, parse_expr!(l), parse_expr!(r)}
  end

  defp parse_cond!({op, _, [l, r]}) when op in [:&&, :and] do
    {:and, parse_cond!(l), parse_cond!(r)}
  end

  defp parse_cond!({op, _, [l, r]}) when op in [:||, :or] do
    {:or, parse_cond!(l), parse_cond!(r)}
  end

  defp parse_cond!({:job_is, _, [{:ctx, _, c}, reader, job]}) when is_atom(c),
    do: {:job_cmp, :==, validate_job_reader!(reader), validate_job!(job)}

  defp parse_cond!({:job_is_not, _, [{:ctx, _, c}, reader, job]}) when is_atom(c),
    do: {:job_cmp, :!=, validate_job_reader!(reader), validate_job!(job)}

  defp parse_cond!(other), do: malformed!("condition", other)

  defp validate_destination!(dest) when is_atom(dest) do
    if dest in BonusKeys.destinations(), do: dest, else: malformed!("bonus destination", dest)
  end

  # A flagged destination validates its param exactly like the unflagged form
  # and additionally requires a non-negative integer trigger flag. The flag is
  # normalized at transpile time, so any complete mask is structurally valid.
  defp validate_destination!({family, {param, flag}})
       when is_atom(family) and is_integer(flag) and flag >= 0 do
    {^family, ^param} = validate_destination!({family, param})
    {family, {param, flag}}
  end

  defp validate_destination!({family, param} = dest) when is_atom(family) do
    case BonusKeys.family_param(family) do
      {:ok, kind} when kind in [:skill, :item, :interval, :monster] ->
        validate_skill_param!(dest, param)

      {:ok, domain} ->
        validate_domain_param!(dest, domain, param)

      :error ->
        malformed!("bonus destination", dest)
    end
  end

  # `bonus3 bAddMonsterDropItem,iid,r,n` renders as a three-element destination
  # literal, which quotes to a `{:{}, _, elems}` node rather than a bare tuple.
  defp validate_destination!({:{}, _, [family, id, race]})
       when is_atom(family) and is_integer(id) and id > 0 and is_atom(race) do
    with {:ok, :item} <- BonusKeys.family_param(family),
         true <- race in BonusKeys.param_domain(:race) do
      {family, id, race}
    else
      _ -> malformed!("bonus destination", {family, id, race})
    end
  end

  defp validate_destination!(dest), do: malformed!("bonus destination", dest)

  defp validate_value!(dest, value) when is_atom(dest) and is_atom(value) do
    with {:ok, domain} <- BonusKeys.value_param(dest),
         true <- value in BonusKeys.param_domain(domain) do
      {:set, dest, value}
    else
      _ -> malformed!("set value", {dest, value})
    end
  end

  defp validate_value!(dest, value), do: malformed!("set value", {dest, value})

  defp validate_skill_param!(dest, param) do
    if is_integer(param) and param > 0, do: dest, else: malformed!("bonus destination", dest)
  end

  defp validate_skill_id!(id) when is_integer(id) and id > 0, do: id
  defp validate_skill_id!(id), do: malformed!("skill id", id)

  # An autocast spec quotes as a map literal; every field is a constant, so the
  # whole shape is checked structurally here.
  defp validate_auto_cast_spec!({:%{}, _, fields}) do
    spec = Map.new(fields)

    with %{trigger: trigger, skill_id: skill_id, flag: flag, force: force} <- spec,
         true <- trigger in [:attack, :when_hit],
         true <- is_integer(skill_id) and skill_id > 0,
         true <- is_integer(flag) and flag >= 0,
         true <- is_integer(force) and force >= 0,
         4 <- map_size(spec) do
      %{trigger: trigger, skill_id: skill_id, flag: flag, force: force}
    else
      _ -> malformed!("auto_cast spec", spec)
    end
  end

  defp validate_auto_cast_spec!(spec), do: malformed!("auto_cast spec", spec)

  defp validate_stat!(stat) when is_atom(stat) do
    if stat in @stat_params, do: stat, else: malformed!("stat param", stat)
  end

  defp validate_stat!(stat), do: malformed!("stat param", stat)

  defp validate_job_reader!(reader) when reader in [:class, :base_class, :base_job], do: reader
  defp validate_job_reader!(reader), do: malformed!("job reader", reader)

  defp validate_job!(job) when is_atom(job) do
    case AvailableJobs.job_name_to_id(job) do
      {:ok, _id} -> job
      _ -> malformed!("job", job)
    end
  end

  defp validate_job!(job), do: malformed!("job", job)

  defp validate_domain_param!(dest, domain, param) do
    if param in BonusKeys.param_domain(domain),
      do: dest,
      else: malformed!("bonus destination", dest)
  end

  defp eval_instrs(instrs, inputs, acc) do
    Enum.reduce(instrs, acc, &eval_instr(&1, inputs, &2))
  end

  defp eval_instr({:bonus, key, expr}, inputs, acc) do
    value = eval_expr(expr, inputs)

    if BonusKeys.max_destination?(key) do
      Map.update(acc, key, value, &max(&1, value))
    else
      Map.update(acc, key, value, &(&1 + value))
    end
  end

  defp eval_instr({:set, key, value}, _inputs, acc), do: Map.put(acc, key, value)

  # An autocast folds into an entry keyed by everything that makes two procs the
  # same arming - trigger, skill, level, attack kinds and force bits - with the
  # per-mille chance as its value. Two items arming the identical proc therefore
  # stack their chances, while the same skill at a different level stays its own
  # entry.
  defp eval_instr({:auto_cast, spec, level_expr, rate_expr}, inputs, acc) do
    level = eval_expr(level_expr, inputs)
    rate = eval_expr(rate_expr, inputs)

    if level > 0 and rate != 0 do
      key = {:auto_cast, {spec.trigger, spec.skill_id, level, spec.flag, spec.force}}
      Map.update(acc, key, rate, &(&1 + rate))
    else
      acc
    end
  end

  defp eval_instr({:grant_skill, skill_id, expr}, inputs, acc) do
    level = eval_expr(expr, inputs)
    Map.update(acc, {:granted_skill, skill_id}, level, &max(&1, level))
  end

  defp eval_instr({:if, condition, then_branch, else_branch}, inputs, acc) do
    branch = if eval_cond(condition, inputs), do: then_branch, else: else_branch
    eval_instrs(branch, inputs, acc)
  end

  defp eval_instr(other, _inputs, _acc), do: malformed!("instruction", other)

  defp eval_expr(int, _inputs) when is_integer(int), do: int

  defp eval_expr(input, inputs) when input in [:refine, :base_level, :job_level],
    do: Map.fetch!(inputs, input)

  defp eval_expr({:skill_lv, skill_id}, inputs),
    do: inputs |> Map.get(:learned_skills, %{}) |> Learned.learned_level(skill_id)

  defp eval_expr({:stat, stat}, inputs),
    do: inputs |> Map.get(:stats, %{}) |> Map.get(stat, 0)

  defp eval_expr({:bool, condition}, inputs), do: if(eval_cond(condition, inputs), do: 1, else: 0)

  defp eval_expr({:+, a, b}, inputs), do: eval_expr(a, inputs) + eval_expr(b, inputs)
  defp eval_expr({:-, a, b}, inputs), do: eval_expr(a, inputs) - eval_expr(b, inputs)
  defp eval_expr({:*, a, b}, inputs), do: eval_expr(a, inputs) * eval_expr(b, inputs)
  defp eval_expr({:div, a, b}, inputs), do: div(eval_expr(a, inputs), eval_expr(b, inputs))
  defp eval_expr({:min, a, b}, inputs), do: min(eval_expr(a, inputs), eval_expr(b, inputs))
  defp eval_expr({:max, a, b}, inputs), do: max(eval_expr(a, inputs), eval_expr(b, inputs))
  defp eval_expr({:pow, a, b}, inputs), do: int_pow(eval_expr(a, inputs), eval_expr(b, inputs))

  defp eval_expr({:ternary, condition, then_expr, else_expr}, inputs) do
    if eval_cond(condition, inputs),
      do: eval_expr(then_expr, inputs),
      else: eval_expr(else_expr, inputs)
  end

  defp eval_expr(other, _inputs), do: malformed!("expression", other)

  defp eval_cond({:>, a, b}, inputs), do: eval_expr(a, inputs) > eval_expr(b, inputs)
  defp eval_cond({:<, a, b}, inputs), do: eval_expr(a, inputs) < eval_expr(b, inputs)
  defp eval_cond({:>=, a, b}, inputs), do: eval_expr(a, inputs) >= eval_expr(b, inputs)
  defp eval_cond({:<=, a, b}, inputs), do: eval_expr(a, inputs) <= eval_expr(b, inputs)
  defp eval_cond({:==, a, b}, inputs), do: eval_expr(a, inputs) == eval_expr(b, inputs)
  defp eval_cond({:!=, a, b}, inputs), do: eval_expr(a, inputs) != eval_expr(b, inputs)
  defp eval_cond({:and, a, b}, inputs), do: eval_cond(a, inputs) and eval_cond(b, inputs)
  defp eval_cond({:or, a, b}, inputs), do: eval_cond(a, inputs) or eval_cond(b, inputs)

  defp eval_cond({:job_cmp, :==, reader, job}, inputs), do: reader_job(reader, inputs) == job
  defp eval_cond({:job_cmp, :!=, reader, job}, inputs), do: reader_job(reader, inputs) != job

  defp eval_cond(other, _inputs), do: malformed!("condition", other)

  # The wearer's job for a reader. An absent `:job_id` input reads as job 0
  # (Novice); `JobLineage` normalizes trans/baby variants for the base readers.
  defp reader_job(reader, inputs) do
    job =
      case AvailableJobs.job_id_to_name(Map.get(inputs, :job_id, 0)) do
        {:ok, name} -> name
        _ -> :novice
      end

    case reader do
      :class -> job
      :base_class -> JobLineage.base_class(job)
      :base_job -> JobLineage.base_job(job)
    end
  end

  # rAthena's `pow` casts a C `double` result to `int`; a non-negative integer
  # exponent is exact via `Integer.pow/2`, and a negative exponent (a fractional
  # magnitude) truncates to `0`.
  defp int_pow(base, exp) when is_integer(base) and is_integer(exp) and exp >= 0,
    do: Integer.pow(base, exp)

  defp int_pow(_base, _exp), do: 0

  @spec malformed!(String.t(), term()) :: no_return()
  defp malformed!(kind, term) do
    raise ArgumentError, "invalid on_equip #{kind}: #{inspect(term)}"
  end
end
