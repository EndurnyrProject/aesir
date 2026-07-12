defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipScript do
  @moduledoc """
  Owner of the `on_equip` bonus-program format: the single place where the
  refine-pure program produced by `EquipCodegen` is defined, serialized,
  deserialized, and evaluated.

  A program is plain data (a list of tuples), not code. It is stored in
  `equip.yml` as nested lists of strings/integers (`encode/1`), decoded back to
  the tuple form at load time through closed whitelists (`decode!/1`), and
  evaluated against an item's refine level during the stats recompute
  (`eval/2`). The evaluator is pure and deterministic in `(program, refine)` —
  the vocabulary admits no session reads and no randomness.

  Corrupt stored data must fail loudly rather than silently degrade: `decode!/1`
  raises on any unknown string, wrong arity, or malformed shape.
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

  @typedoc "The YAML-safe encoded form: nested lists of strings and integers."
  @type encoded :: [list()]

  # Arithmetic operators are stored as alphabetic words rather than their
  # symbols: a bare `+` scalar is not YAML-safe (`Ymlr` writes it unquoted and
  # `YamlElixir` reads it back as the integer 0), which silently corrupts the
  # program on load. The comparison/logic operators below round-trip through
  # YAML unchanged and stay symbolic.
  @arith_ops %{"add" => :+, "sub" => :-, "mul" => :*, "div" => :div}
  @arith_names Map.new(@arith_ops, fn {name, op} -> {op, name} end)
  @compare_ops %{">" => :>, "<" => :<, ">=" => :>=, "<=" => :<=, "==" => :==, "!=" => :!=}
  @logic_ops %{"and" => :and, "or" => :or}

  @doc """
  Serializes a program to a YAML-safe nested list of strings and integers.
  Integers are preserved; atoms become their string names.
  """
  @spec encode(program()) :: encoded()
  def encode(program) when is_list(program), do: Enum.map(program, &encode_instr/1)

  @doc """
  Strictly deserializes an encoded program back to the tuple form.

  Every string is mapped to an atom only through closed whitelists (destination
  atoms via `BonusKeys.destinations/0`, a fixed operator set, and the statement
  tags `bonus`/`if`). Any unknown string, wrong arity, or malformed shape raises
  `ArgumentError` — corrupt data must not load silently.
  """
  @spec decode!(encoded()) :: program()
  def decode!(encoded) when is_list(encoded), do: Enum.map(encoded, &decode_instr!/1)

  @doc """
  Evaluates a program against a refine level, folding every `:bonus` into a
  `%{destination => integer}` accumulator. Pure and deterministic in
  `(program, refine)`.
  """
  @spec eval(program(), integer()) :: %{atom() => integer()}
  def eval(program, refine) when is_list(program) and is_integer(refine) do
    eval_instrs(program, refine, %{})
  end

  defp encode_instr({:bonus, dest, expr}) when is_atom(dest) do
    ["bonus", Atom.to_string(dest), encode_expr(expr)]
  end

  defp encode_instr({:if, condition, then_branch, else_branch}) do
    ["if", encode_cond(condition), encode(then_branch), encode(else_branch)]
  end

  defp encode_expr(int) when is_integer(int), do: int
  defp encode_expr(:refine), do: "refine"

  defp encode_expr({op, left, right}) when op in [:+, :-, :*, :div] do
    [Map.fetch!(@arith_names, op), encode_expr(left), encode_expr(right)]
  end

  defp encode_cond({op, left, right}) when op in [:>, :<, :>=, :<=, :==, :!=] do
    [Atom.to_string(op), encode_expr(left), encode_expr(right)]
  end

  defp encode_cond({op, left, right}) when op in [:and, :or] do
    [Atom.to_string(op), encode_cond(left), encode_cond(right)]
  end

  defp decode_instr!(["bonus", dest, expr]) when is_binary(dest) do
    {:bonus, decode_destination!(dest), decode_expr!(expr)}
  end

  defp decode_instr!(["if", condition, then_branch, else_branch])
       when is_list(then_branch) and is_list(else_branch) do
    {:if, decode_cond!(condition), decode!(then_branch), decode!(else_branch)}
  end

  defp decode_instr!(other), do: malformed!("instruction", other)

  defp decode_expr!(int) when is_integer(int), do: int
  defp decode_expr!("refine"), do: :refine

  defp decode_expr!([op, left, right]) when is_binary(op) do
    case Map.fetch(@arith_ops, op) do
      {:ok, atom} -> {atom, decode_expr!(left), decode_expr!(right)}
      :error -> malformed!("arithmetic operator", op)
    end
  end

  defp decode_expr!(other), do: malformed!("expression", other)

  defp decode_cond!([op, left, right]) when is_binary(op) do
    cond do
      Map.has_key?(@compare_ops, op) ->
        {Map.fetch!(@compare_ops, op), decode_expr!(left), decode_expr!(right)}

      Map.has_key?(@logic_ops, op) ->
        {Map.fetch!(@logic_ops, op), decode_cond!(left), decode_cond!(right)}

      true ->
        malformed!("condition operator", op)
    end
  end

  defp decode_cond!(other), do: malformed!("condition", other)

  defp decode_destination!(dest) do
    case Enum.find(BonusKeys.destinations(), &(Atom.to_string(&1) == dest)) do
      nil -> malformed!("bonus destination", dest)
      atom -> atom
    end
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
