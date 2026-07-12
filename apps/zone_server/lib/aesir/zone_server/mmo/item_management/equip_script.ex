defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScript do
  @moduledoc """
  Owner of the `on_equip` bonus-program format: the single place where the
  refine-pure program produced by `EquipCodegen` is defined, serialized,
  deserialized, and evaluated.

  A program is plain data (a list of tuples). It is stored in `equip.yml` as an
  Elixir DSL source string in the same style as `on_use` (`to_source/1`), e.g.
  `bonus(ctx, :int, 3)` or

      ctx = bonus(ctx, :vit, 5)
      ctx = bonus(ctx, :def, 10)
      ctx

  and parsed back to the tuple form at load time through a closed vocabulary
  (`parse!/1`): `bonus/3`, `refine/1`, `+ - *` and `div/2`, comparisons,
  `&&`/`||`, and `if/else`. Unlike `on_use` the source is never compiled to
  code — the equip corpus (~13k items) is far past the BEAM clause-count
  ceiling — so `eval/2` interprets the tuple program against an item's refine
  level during the stats recompute. The evaluator is pure and deterministic in
  `(program, refine)` — the vocabulary admits no session reads and no
  randomness.

  Corrupt stored data must fail loudly rather than silently degrade: `parse!/1`
  raises on any construct outside the vocabulary, any unknown bonus
  destination, or malformed shape.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  @type arith_op :: :+ | :- | :* | :div
  @type compare_op :: :> | :< | :>= | :<= | :== | :!=
  @type logic_op :: :and | :or

  @typedoc "A refine-pure arithmetic expression evaluating to an integer."
  @type expr :: integer() | :refine | {arith_op(), expr(), expr()}

  @typedoc "A refine-pure boolean condition gating an `:if` instruction."
  @type condition ::
          {compare_op(), expr(), expr()} | {logic_op(), condition(), condition()}

  @typedoc "A single bonus program statement."
  @type instr :: {:bonus, atom(), expr()} | {:if, condition(), [instr()], [instr()]}

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
  closed vocabulary; bonus destinations are validated through
  `BonusKeys.destinations/0`. Any unknown call, operator, destination, or
  malformed shape raises `ArgumentError` — corrupt data must not load silently.
  """
  @spec parse!(String.t()) :: program()
  def parse!(source) when is_binary(source) do
    source |> Code.string_to_quoted!() |> parse_stmts()
  end

  @doc """
  Evaluates a program against a refine level, folding every `:bonus` into a
  `%{destination => integer}` accumulator. Pure and deterministic in
  `(program, refine)`.
  """
  @spec eval(program(), integer()) :: %{atom() => integer()}
  def eval(program, refine) when is_list(program) and is_integer(refine) do
    eval_instrs(program, refine, %{})
  end

  defp render_stmts([]), do: "ctx"
  defp render_stmts([instr]), do: render_instr(instr)

  defp render_stmts(instrs) do
    instrs
    |> Enum.map(&"ctx = #{render_instr(&1)}")
    |> Kernel.++(["ctx"])
    |> Enum.join("\n")
  end

  defp render_instr({:bonus, dest, expr}) when is_atom(dest) do
    "bonus(ctx, #{inspect(dest)}, #{render_expr(expr)})"
  end

  defp render_instr({:if, condition, then_branch, else_branch}) do
    "if #{render_cond(condition)} do\n" <>
      "#{indent(render_stmts(then_branch))}\nelse\n#{indent(render_stmts(else_branch))}\nend"
  end

  defp render_expr(int) when is_integer(int), do: Integer.to_string(int)
  defp render_expr(:refine), do: "refine(ctx)"
  defp render_expr({:div, l, r}), do: "div(#{render_expr(l)}, #{render_expr(r)})"

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

  defp parse_instr!({:bonus, _, [{:ctx, _, c}, dest, expr]})
       when is_atom(c) and is_atom(dest) do
    {:bonus, validate_destination!(dest), parse_expr!(expr)}
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

  defp parse_expr!({op, _, [l, r]}) when op in [:+, :-, :*, :div] do
    {op, parse_expr!(l), parse_expr!(r)}
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

  defp validate_destination!(dest) do
    if dest in BonusKeys.destinations(), do: dest, else: malformed!("bonus destination", dest)
  end

  defp eval_instrs(instrs, refine, acc) do
    Enum.reduce(instrs, acc, &eval_instr(&1, refine, &2))
  end

  defp eval_instr({:bonus, key, expr}, refine, acc) do
    value = eval_expr(expr, refine)
    Map.update(acc, key, value, &(&1 + value))
  end

  defp eval_instr({:if, condition, then_branch, else_branch}, refine, acc) do
    branch = if eval_cond(condition, refine), do: then_branch, else: else_branch
    eval_instrs(branch, refine, acc)
  end

  defp eval_instr(other, _refine, _acc), do: malformed!("instruction", other)

  defp eval_expr(int, _refine) when is_integer(int), do: int
  defp eval_expr(:refine, refine), do: refine
  defp eval_expr({:+, a, b}, refine), do: eval_expr(a, refine) + eval_expr(b, refine)
  defp eval_expr({:-, a, b}, refine), do: eval_expr(a, refine) - eval_expr(b, refine)
  defp eval_expr({:*, a, b}, refine), do: eval_expr(a, refine) * eval_expr(b, refine)
  defp eval_expr({:div, a, b}, refine), do: div(eval_expr(a, refine), eval_expr(b, refine))
  defp eval_expr(other, _refine), do: malformed!("expression", other)

  defp eval_cond({:>, a, b}, refine), do: eval_expr(a, refine) > eval_expr(b, refine)
  defp eval_cond({:<, a, b}, refine), do: eval_expr(a, refine) < eval_expr(b, refine)
  defp eval_cond({:>=, a, b}, refine), do: eval_expr(a, refine) >= eval_expr(b, refine)
  defp eval_cond({:<=, a, b}, refine), do: eval_expr(a, refine) <= eval_expr(b, refine)
  defp eval_cond({:==, a, b}, refine), do: eval_expr(a, refine) == eval_expr(b, refine)
  defp eval_cond({:!=, a, b}, refine), do: eval_expr(a, refine) != eval_expr(b, refine)
  defp eval_cond({:and, a, b}, refine), do: eval_cond(a, refine) and eval_cond(b, refine)
  defp eval_cond({:or, a, b}, refine), do: eval_cond(a, refine) or eval_cond(b, refine)
  defp eval_cond(other, _refine), do: malformed!("condition", other)

  @spec malformed!(String.t(), term()) :: no_return()
  defp malformed!(kind, term) do
    raise ArgumentError, "invalid on_equip #{kind}: #{inspect(term)}"
  end
end
