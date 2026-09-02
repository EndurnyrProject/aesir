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
  (`parse!/1`): `bonus/3`, `autobonus/4`, `status_start/4`, `status_end/2`,
  `refine/1`, `base_level/1`, `job_level/1`, `+ - *`, `div/2`, `min/2`,
  `max/2`, `pow/2`, comparisons, `&&`/`||`, `job_is/3`, `job_is_not/3`,
  `bool/2`, `if/else` statements, and the inline
  `if(cond, do: a, else: b)` ternary expression. Unlike `on_use` the source is
  never compiled to code — the equip corpus (~13k items) is far past the BEAM
  clause-count ceiling — so `evaluate/2` interprets the tuple program against
  the `t:inputs/0` map during the stats recompute. `eval/2` remains the
  modifier-only compatibility entry point. The evaluator is
  pure and deterministic in `(program, inputs)` — the three inputs (the item's
  refine, the wearer's base and job level) are the only reads the vocabulary
  admits, and there is no randomness. Level inputs change on level-up, which is
  why the stats recompute re-evaluates programs (`Stats.apply_equipment_modifiers`
  caches `worn_items` for exactly that refold).

  Corrupt stored data must fail loudly rather than silently degrade: `parse!/1`
  raises on any construct outside the vocabulary, any unknown bonus
  destination, or malformed shape.

  ## Effects and autobonuses

  Status lifecycle instructions evaluate their duration and value from the
  same pure inputs as modifiers. Autobonus instructions keep their trigger,
  battle flag, and nested programs as validated data while evaluating rate and
  duration into ordered registrations. `:infinite` is reserved for status
  duration; non-positive finite status durations and autobonus rates or
  durations are omitted.

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

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript.Result
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
  integer skill or item id, a positive-integer interval in milliseconds for the
  periodic HP-regen/loss families, or a normalized battle flag for vanish
  families. A key written with a trigger-condition
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
  level randomization. An `:on_skill` proc additionally names the
  `:trigger_skill` whose use fires it, and carries no attack kinds. The level
  and chance are expressions, so they ride the instruction rather than this map.
  """
  @type auto_cast_spec :: %{
          :trigger => :attack | :when_hit | :on_skill,
          :skill_id => pos_integer(),
          :flag => non_neg_integer(),
          :force => non_neg_integer(),
          optional(:trigger_skill) => pos_integer()
        }

  @typedoc "The constant trigger and nested programs of an autobonus instruction."
  @type autobonus_spec :: %{
          trigger: :attack | :when_hit | {:on_skill, pos_integer()},
          battle_flag: non_neg_integer(),
          primary: program(),
          secondary: program()
        }

  @typedoc "A status lifecycle effect emitted by an evaluated equipment program."
  @type effect ::
          {:status_start, atom(), pos_integer() | :infinite, integer()}
          | {:status_end, atom()}

  @typedoc "A temporary equipment-program registration emitted by evaluation."
  @type autobonus :: %{
          trigger: :attack | :when_hit | {:on_skill, pos_integer()},
          rate: integer(),
          duration_ms: pos_integer(),
          battle_flag: non_neg_integer(),
          primary: program(),
          secondary: program()
        }

  @typedoc "A single bonus program statement."
  @type instr ::
          {:bonus, dest(), expr()}
          | {:set, dest(), value()}
          | {:grant_skill, pos_integer(), expr()}
          | {:auto_cast, auto_cast_spec(), expr(), expr()}
          | {:autobonus, autobonus_spec(), expr(), expr()}
          | {:status_start, atom(), expr() | :infinite, expr()}
          | {:status_end, atom()}
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
  Evaluates a program against its `t:inputs/0` into modifiers, autobonus
  registrations, and ordered status effects. Pure and deterministic in
  `(program, inputs)`; an input the program reads but the map lacks raises.
  """
  @spec evaluate(program(), inputs()) :: Result.t()
  def evaluate(program, inputs) when is_list(program) and is_map(inputs) do
    result =
      eval_instrs(program, inputs, %Result{modifiers: %{}, autobonuses: [], effects: []})

    %{
      result
      | autobonuses: Enum.reverse(result.autobonuses),
        effects: Enum.reverse(result.effects)
    }
  end

  @doc """
  Evaluates a program and returns only its modifier map.

  This is the compatibility entry point for existing equipment-stat callers.
  """
  @spec eval(program(), inputs()) :: %{dest() => integer() | value()}
  def eval(program, inputs), do: evaluate(program, inputs).modifiers

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

  defp render_instr({:autobonus, spec, rate, duration}) do
    "autobonus(ctx, #{inspect(spec, limit: :infinity)}, #{render_expr(rate)}, #{render_expr(duration)})"
  end

  defp render_instr({:status_start, status, duration, value}) do
    "status_start(ctx, #{inspect(status)}, #{render_duration(duration)}, #{render_expr(value)})"
  end

  defp render_instr({:status_end, status}) do
    "status_end(ctx, #{inspect(status)})"
  end

  defp render_instr({:if, condition, then_branch, else_branch}) do
    "if #{render_cond(condition)} do\n" <>
      "#{indent(render_stmts(then_branch))}\nelse\n#{indent(render_stmts(else_branch))}\nend"
  end

  defp render_duration(:infinite), do: ":infinite"
  defp render_duration(expr), do: render_expr(expr)

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

  defp parse_instr!({:autobonus, _, [{:ctx, _, c}, spec, rate, duration]}) when is_atom(c) do
    {:autobonus, validate_autobonus_spec!(spec), parse_expr!(rate), parse_expr!(duration)}
  end

  defp parse_instr!({:status_start, _, [{:ctx, _, c}, status, duration, value]})
       when is_atom(c) do
    {:status_start, validate_status!(status), parse_duration!(duration), parse_expr!(value)}
  end

  defp parse_instr!({:status_end, _, [{:ctx, _, c}, status]}) when is_atom(c) do
    {:status_end, validate_status!(status)}
  end

  defp parse_instr!({:if, _, [condition, [do: then_q, else: else_q]]}) do
    {:if, parse_cond!(condition), parse_stmts(then_q), parse_stmts(else_q)}
  end

  defp parse_instr!({:if, _, [condition, [do: then_q]]}) do
    {:if, parse_cond!(condition), parse_stmts(then_q), []}
  end

  defp parse_instr!(other), do: malformed!("instruction", other)

  defp parse_duration!(:infinite), do: :infinite
  defp parse_duration!(duration), do: parse_expr!(duration)

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
      {:ok, :item_group} ->
        validate_item_group_param!(dest, param)

      {:ok, kind} when kind in [:skill, :item, :interval, :monster, :battle] ->
        validate_skill_param!(dest, param)

      {:ok, domain} ->
        validate_domain_param!(dest, domain, param)

      :error ->
        malformed!("bonus destination", dest)
    end
  end

  # `bonus3 bAddMonsterDropItem,iid,r,n` renders as a three-element destination
  # literal, which quotes to a `{:{}, _, elems}` node rather than a bare tuple.
  # `{:add_eff_on_skill, trigger_skill, sc}`: a status inflicted when one named
  # skill lands.
  defp validate_destination!({:{}, _, [:add_eff_on_skill, skill_id, status]})
       when is_integer(skill_id) and skill_id > 0 and is_atom(status) do
    if status in BonusKeys.param_domain(:status) do
      {:add_eff_on_skill, skill_id, status}
    else
      malformed!("bonus destination", {:add_eff_on_skill, skill_id, status})
    end
  end

  defp validate_destination!({:{}, _, [family, id, gate]})
       when is_atom(family) and is_integer(id) and id > 0 do
    with {:ok, :item} <- BonusKeys.family_param(family),
         true <- valid_drop_gate?(gate) do
      {family, id, gate}
    else
      _ -> malformed!("bonus destination", {family, id, gate})
    end
  end

  defp validate_destination!(dest), do: malformed!("bonus destination", dest)

  # A bonus drop is gated either on the slain mob's race or on one monster id.
  defp valid_drop_gate?(gate) when is_atom(gate), do: gate in BonusKeys.param_domain(:race)
  defp valid_drop_gate?(gate) when is_integer(gate), do: gate > 0
  defp valid_drop_gate?(_gate), do: false

  defp validate_value!(dest, value) when is_atom(dest) and is_atom(value) do
    with {:ok, domain} <- BonusKeys.value_param(dest),
         true <- value in BonusKeys.param_domain(domain) do
      {:set, dest, value}
    else
      _ -> malformed!("set value", {dest, value})
    end
  end

  defp validate_value!(dest, value), do: malformed!("set value", {dest, value})

  defp validate_item_group_param!(dest, param) do
    if is_atom(param), do: dest, else: malformed!("bonus destination", dest)
  end

  defp validate_skill_param!(dest, param) do
    if is_integer(param) and param > 0, do: dest, else: malformed!("bonus destination", dest)
  end

  defp validate_skill_id!(id) when is_integer(id) and id > 0, do: id
  defp validate_skill_id!(id), do: malformed!("skill id", id)

  defp validate_status!(status) when is_atom(status), do: status
  defp validate_status!(status), do: malformed!("status", status)

  # An autocast spec quotes as a map literal; every field is a constant, so the
  # whole shape is checked structurally here.
  defp validate_auto_cast_spec!({:%{}, _, fields}) do
    spec = Map.new(fields)

    with %{trigger: trigger, skill_id: skill_id, flag: flag, force: force} <- spec,
         true <- trigger in [:attack, :when_hit, :on_skill],
         true <- is_integer(skill_id) and skill_id > 0,
         true <- is_integer(flag) and flag >= 0,
         true <- is_integer(force) and force >= 0,
         true <- valid_trigger_skill?(spec, trigger) do
      spec
    else
      _ -> malformed!("auto_cast spec", spec)
    end
  end

  defp validate_auto_cast_spec!(spec), do: malformed!("auto_cast spec", spec)

  defp validate_autobonus_spec!({:%{}, _, _} = quoted) do
    quoted
    |> literal!()
    |> validate_autobonus_spec!()
  end

  defp validate_autobonus_spec!(
         %{trigger: trigger, battle_flag: battle_flag, primary: primary, secondary: secondary} =
           spec
       ) do
    with true <- map_size(spec) == 4,
         true <- valid_autobonus_trigger?(trigger),
         true <- is_integer(battle_flag) and battle_flag >= 0,
         primary when is_list(primary) <- validate_program!(primary),
         secondary when is_list(secondary) <- validate_program!(secondary) do
      %{spec | primary: primary, secondary: secondary}
    else
      _ -> malformed!("autobonus spec", spec)
    end
  end

  defp validate_autobonus_spec!(spec), do: malformed!("autobonus spec", spec)

  defp valid_autobonus_trigger?(trigger) when trigger in [:attack, :when_hit], do: true
  defp valid_autobonus_trigger?({:on_skill, id}), do: is_integer(id) and id > 0
  defp valid_autobonus_trigger?(_trigger), do: false

  defp validate_program!(program) when is_list(program) do
    case program |> render_stmts() |> Code.string_to_quoted!() |> parse_stmts() do
      ^program -> program
      _other -> malformed!("autobonus program", program)
    end
  rescue
    FunctionClauseError -> malformed!("autobonus program", program)
  end

  defp validate_program!(program), do: malformed!("autobonus program", program)

  defp literal!(term) when is_atom(term) or is_integer(term) or is_binary(term), do: term
  defp literal!({:-, _, [integer]}) when is_integer(integer), do: -integer
  defp literal!(list) when is_list(list), do: Enum.map(list, &literal!/1)
  defp literal!({left, right}), do: {literal!(left), literal!(right)}
  defp literal!({:{}, _, values}), do: values |> Enum.map(&literal!/1) |> List.to_tuple()

  defp literal!({:%{}, _, fields}) do
    Map.new(fields, fn {key, value} -> {literal!(key), literal!(value)} end)
  end

  defp literal!(term), do: malformed!("literal", term)

  # Only an on-skill proc names a triggering skill, and it must name one.
  defp valid_trigger_skill?(spec, :on_skill) do
    map_size(spec) == 5 and is_integer(spec[:trigger_skill]) and spec[:trigger_skill] > 0
  end

  defp valid_trigger_skill?(spec, _trigger), do: map_size(spec) == 4

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

  defp eval_instr({:bonus, key, expr}, inputs, %Result{modifiers: modifiers} = result) do
    value = eval_expr(expr, inputs)

    modifiers =
      cond do
        BonusKeys.overwrite_destination?(key) -> Map.put(modifiers, key, value)
        BonusKeys.max_destination?(key) -> Map.update(modifiers, key, value, &max(&1, value))
        true -> Map.update(modifiers, key, value, &(&1 + value))
      end

    %{result | modifiers: modifiers}
  end

  defp eval_instr({:set, key, value}, _inputs, %Result{} = result) do
    %{result | modifiers: Map.put(result.modifiers, key, value)}
  end

  # An autocast folds into an entry keyed by everything that makes two procs the
  # same arming - trigger, skill, level, attack kinds and force bits - with the
  # per-mille chance as its value. Two items arming the identical proc therefore
  # stack their chances, while the same skill at a different level stays its own
  # entry.
  defp eval_instr({:auto_cast, spec, level_expr, rate_expr}, inputs, %Result{} = result) do
    level = eval_expr(level_expr, inputs)
    rate = eval_expr(rate_expr, inputs)

    if level > 0 and rate != 0 do
      key = auto_cast_key(spec, level)
      modifiers = Map.update(result.modifiers, key, rate, &(&1 + rate))
      %{result | modifiers: modifiers}
    else
      result
    end
  end

  defp eval_instr({:grant_skill, skill_id, expr}, inputs, %Result{} = result) do
    level = eval_expr(expr, inputs)
    key = {:granted_skill, skill_id}
    %{result | modifiers: Map.update(result.modifiers, key, level, &max(&1, level))}
  end

  defp eval_instr({:autobonus, spec, rate_expr, duration_expr}, inputs, %Result{} = result) do
    rate = eval_expr(rate_expr, inputs)
    duration = eval_expr(duration_expr, inputs)

    if rate > 0 and duration > 0 do
      autobonus = spec |> Map.put(:rate, rate) |> Map.put(:duration_ms, duration)
      %{result | autobonuses: [autobonus | result.autobonuses]}
    else
      result
    end
  end

  defp eval_instr({:status_start, status, :infinite, value_expr}, inputs, %Result{} = result) do
    effect = {:status_start, status, :infinite, eval_expr(value_expr, inputs)}
    %{result | effects: [effect | result.effects]}
  end

  defp eval_instr({:status_start, status, duration_expr, value_expr}, inputs, %Result{} = result) do
    duration = eval_expr(duration_expr, inputs)

    if duration > 0 do
      effect = {:status_start, status, duration, eval_expr(value_expr, inputs)}
      %{result | effects: [effect | result.effects]}
    else
      result
    end
  end

  defp eval_instr({:status_end, status}, _inputs, %Result{} = result) do
    %{result | effects: [{:status_end, status} | result.effects]}
  end

  defp eval_instr({:if, condition, then_branch, else_branch}, inputs, acc) do
    branch = if eval_cond(condition, inputs), do: then_branch, else: else_branch
    eval_instrs(branch, inputs, acc)
  end

  defp eval_instr(other, _inputs, _acc), do: malformed!("instruction", other)
  # An on-skill proc is keyed by the skill that fires it instead of by the kinds
  # of attack that do, so the two live in separate key families.
  defp auto_cast_key(%{trigger: :on_skill} = spec, level) do
    {:auto_cast_on_skill, {spec.trigger_skill, spec.skill_id, level, spec.force}}
  end

  defp auto_cast_key(spec, level) do
    {:auto_cast, {spec.trigger, spec.skill_id, level, spec.flag, spec.force}}
  end

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
