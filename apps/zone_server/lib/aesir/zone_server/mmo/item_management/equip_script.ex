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
  `+ - *` and `div/2`, comparisons, `&&`/`||`, `if/else` statements, and the
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
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  @type arith_op :: :+ | :- | :* | :div
  @type compare_op :: :> | :< | :>= | :<= | :== | :!=
  @type logic_op :: :and | :or

  @typedoc "The evaluation inputs: the item's refine and the wearer's levels."
  @type inputs :: %{refine: integer(), base_level: integer(), job_level: integer()}

  @typedoc """
  An input-pure arithmetic expression evaluating to an integer. `{:ternary, c, a, b}`
  is the rAthena `c ? a : b` conditional expression: `a` when the condition
  holds, `b` otherwise.
  """
  @type expr ::
          integer()
          | :refine
          | :base_level
          | :job_level
          | {arith_op(), expr(), expr()}
          | {:ternary, condition(), expr(), expr()}

  @typedoc "An input-pure boolean condition gating an `:if` instruction or a ternary."
  @type condition ::
          {compare_op(), expr(), expr()} | {logic_op(), condition(), condition()}

  @typedoc """
  A bonus destination: a flat atom for section-3 keys, or a `{family, param}`
  tuple for parameterized `bonus2` keys — `param` is an atom drawn from the
  family's `BonusKeys` domain (race/element/size/class/race2) or a positive
  integer skill or item id.
  """
  @type dest :: atom() | {atom(), atom() | pos_integer()}

  @typedoc """
  A constant-valued destination assignment, for the `bonus` keys whose argument
  is a constant rather than an amount (`bonus bAtkEle,Ele_Fire;`). Unlike
  `:bonus` these do not sum — the last one evaluated wins.
  """
  @type value :: atom()

  @typedoc "A single bonus program statement."
  @type instr ::
          {:bonus, dest(), expr()}
          | {:set, dest(), value()}
          | {:if, condition(), [instr()], [instr()]}

  @typedoc "A bonus program: an ordered list of instructions."
  @type program :: [instr()]

  @compare_ops [:>, :<, :>=, :<=, :==, :!=]
  @plain_arith_ops [:+, :-, :*]

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

  defp render_instr({:if, condition, then_branch, else_branch}) do
    "if #{render_cond(condition)} do\n" <>
      "#{indent(render_stmts(then_branch))}\nelse\n#{indent(render_stmts(else_branch))}\nend"
  end

  defp render_expr(int) when is_integer(int), do: Integer.to_string(int)
  defp render_expr(:refine), do: "refine(ctx)"
  defp render_expr(:base_level), do: "base_level(ctx)"
  defp render_expr(:job_level), do: "job_level(ctx)"
  defp render_expr({:div, l, r}), do: "div(#{render_expr(l)}, #{render_expr(r)})"

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

  defp parse_expr!({op, _, [l, r]}) when op in [:+, :-, :*, :div] do
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

  defp parse_cond!(other), do: malformed!("condition", other)

  defp validate_destination!(dest) when is_atom(dest) do
    if dest in BonusKeys.destinations(), do: dest, else: malformed!("bonus destination", dest)
  end

  defp validate_destination!({family, param} = dest) when is_atom(family) do
    case BonusKeys.family_param(family) do
      {:ok, kind} when kind in [:skill, :item] -> validate_skill_param!(dest, param)
      {:ok, domain} -> validate_domain_param!(dest, domain, param)
      :error -> malformed!("bonus destination", dest)
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

  defp eval_instr({:if, condition, then_branch, else_branch}, inputs, acc) do
    branch = if eval_cond(condition, inputs), do: then_branch, else: else_branch
    eval_instrs(branch, inputs, acc)
  end

  defp eval_instr(other, _inputs, _acc), do: malformed!("instruction", other)

  defp eval_expr(int, _inputs) when is_integer(int), do: int

  defp eval_expr(input, inputs) when input in [:refine, :base_level, :job_level],
    do: Map.fetch!(inputs, input)

  defp eval_expr({:+, a, b}, inputs), do: eval_expr(a, inputs) + eval_expr(b, inputs)
  defp eval_expr({:-, a, b}, inputs), do: eval_expr(a, inputs) - eval_expr(b, inputs)
  defp eval_expr({:*, a, b}, inputs), do: eval_expr(a, inputs) * eval_expr(b, inputs)
  defp eval_expr({:div, a, b}, inputs), do: div(eval_expr(a, inputs), eval_expr(b, inputs))

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
  defp eval_cond(other, _inputs), do: malformed!("condition", other)

  @spec malformed!(String.t(), term()) :: no_return()
  defp malformed!(kind, term) do
    raise ArgumentError, "invalid on_equip #{kind}: #{inspect(term)}"
  end
end
