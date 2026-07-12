defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen do
  @moduledoc """
  Final stage of the equip-script transpiler: `Parser` AST -> refine-pure
  `EquipScript.program()` term.

  Walks the parsed statement list of an equip item's rAthena `Script`, consulting
  `BonusKeys` for supported destinations, and emits a plain-data bonus program.
  The emit is all-or-nothing (spec goal 5): the first out-of-vocabulary construct
  aborts the whole item with `{:error, {:unsupported, detail}}` and produces no
  program — the runtime never sees a partial one.

  ## Refine-variable inlining

  The `.@r = getrefine();` idiom is handled at transpile time. A top-level
  assignment binds its scoped-var name to a compiled, refine-pure expression in a
  transpile-time environment; every later `.@r` use is substituted, so the emitted
  program is pure in a single input (refine) and the evaluator needs no variable
  environment. Later assignments shadow earlier ones.

  Assignments inside an `if` branch are rejected (`{:conditional_assignment, name}`):
  the value would depend on the branch taken, making inlining unsound. Branches are
  therefore walked with the environment read-only.

  ## Vocabulary

  - `{:assign, name, ast}` at the top level — inline-bind, emit nothing.
  - `bonus bKey,amount` — `{:bonus, destination, expr}` when `bKey` resolves via
    `BonusKeys` (miss -> `{:unknown_bonus_key, key}`); any other command name and
    any other `bonus` shape (`bonus2`..`bonus5` parse as ordinary calls) is
    unsupported.
  - `if (cond) then [else]` — `{:if, cond, then, else}` when `cond` is a
    refine-pure boolean over comparisons / `&&` / `||`; a non-refine read such as
    `BaseLevel` is unsupported.
  - Expressions are refine-pure only: integer literals, `getrefine()` -> `:refine`,
    inlined `.@var`, and `+ - * /` arithmetic (`/` -> `:div`, matching C/Elixir
    truncating integer division). `rand(...)` and every other call are unsupported.

  A program that compiles to zero instructions (script was only assignments) yields
  `{:ok, []}`, which the importer stores as no `on_equip`.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  @type detail :: term()

  @arith_ops [:+, :-, :*, :/]
  @compare_ops [:>, :<, :>=, :<=, :==, :!=]

  @spec generate([tuple()]) ::
          {:ok, EquipScript.program()} | {:error, {:unsupported, detail()}}
  def generate(stmts) when is_list(stmts), do: reduce_top(stmts, %{}, [])

  @spec reduce_top([tuple()], %{String.t() => EquipScript.expr()}, [EquipScript.instr()]) ::
          {:ok, EquipScript.program()} | {:error, {:unsupported, detail()}}
  defp reduce_top([], _env, acc), do: {:ok, Enum.reverse(acc)}

  defp reduce_top([{:assign, name, ast} | rest], env, acc) do
    with {:ok, expr} <- compile_expr(ast, env) do
      reduce_top(rest, Map.put(env, name, expr), acc)
    end
  end

  defp reduce_top([stmt | rest], env, acc) do
    with {:ok, instr} <- compile_instr(stmt, env) do
      reduce_top(rest, env, [instr | acc])
    end
  end

  @spec reduce_branch([tuple()], %{String.t() => EquipScript.expr()}) ::
          {:ok, [EquipScript.instr()]} | {:error, {:unsupported, detail()}}
  defp reduce_branch(stmts, env) do
    Enum.reduce_while(stmts, {:ok, []}, fn stmt, {:ok, acc} ->
      case branch_instr(stmt, env) do
        {:ok, instr} -> {:cont, {:ok, [instr | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  @spec branch_instr(tuple(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp branch_instr({:assign, name, _ast}, _env),
    do: unsupported({:conditional_assignment, name})

  defp branch_instr(stmt, env), do: compile_instr(stmt, env)

  @spec compile_instr(tuple(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_instr({:call, "bonus", [{:const, key}, amount]}, env) do
    with {:ok, dest} <- destination(key),
         {:ok, expr} <- compile_expr(amount, env) do
      {:ok, {:bonus, dest, expr}}
    end
  end

  defp compile_instr({:call, "bonus", args}, _env), do: unsupported({:bonus_shape, args})

  defp compile_instr({:if, cond_expr, then_stmts, else_stmts}, env) do
    with {:ok, condition} <- compile_cond(cond_expr, env),
         {:ok, then_instrs} <- reduce_branch(then_stmts, env),
         {:ok, else_instrs} <- reduce_branch(else_stmts, env) do
      {:ok, {:if, condition, then_instrs, else_instrs}}
    end
  end

  defp compile_instr({:call, name, _args}, _env), do: unsupported({:unsupported_command, name})
  defp compile_instr(other, _env), do: unsupported({:statement, other})

  @spec destination(String.t()) :: {:ok, atom()} | {:error, {:unsupported, detail()}}
  defp destination(key) do
    case BonusKeys.destination(key) do
      {:ok, dest} -> {:ok, dest}
      :error -> unsupported({:unknown_bonus_key, key})
    end
  end

  @spec compile_expr(term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.expr()} | {:error, {:unsupported, detail()}}
  defp compile_expr(int, _env) when is_integer(int), do: {:ok, int}

  defp compile_expr({:call_expr, "getrefine", []}, _env), do: {:ok, :refine}

  defp compile_expr({:var, name}, env) do
    case Map.fetch(env, name) do
      {:ok, expr} -> {:ok, expr}
      :error -> unsupported({:unassigned_var, name})
    end
  end

  defp compile_expr({:binop, op, lhs, rhs}, env) when op in @arith_ops do
    with {:ok, l} <- compile_expr(lhs, env),
         {:ok, r} <- compile_expr(rhs, env) do
      {:ok, {arith_op(op), l, r}}
    end
  end

  defp compile_expr({:call_expr, name, _args}, _env), do: unsupported({:unsupported_call, name})
  defp compile_expr(other, _env), do: unsupported({:expression, other})

  @spec compile_cond(term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.condition()} | {:error, {:unsupported, detail()}}
  defp compile_cond({:binop, op, lhs, rhs}, env) when op in @compare_ops do
    with {:ok, l} <- compile_expr(lhs, env),
         {:ok, r} <- compile_expr(rhs, env) do
      {:ok, {op, l, r}}
    end
  end

  defp compile_cond({:logic, op, lhs, rhs}, env) do
    with {:ok, l} <- compile_cond(lhs, env),
         {:ok, r} <- compile_cond(rhs, env) do
      {:ok, {logic_op(op), l, r}}
    end
  end

  defp compile_cond(other, _env), do: unsupported({:condition, other})

  @spec arith_op(atom()) :: EquipScript.arith_op()
  defp arith_op(:/), do: :div
  defp arith_op(op), do: op

  @spec logic_op(atom()) :: EquipScript.logic_op()
  defp logic_op(:&&), do: :and
  defp logic_op(:||), do: :or

  @spec unsupported(detail()) :: {:error, {:unsupported, detail()}}
  defp unsupported(detail), do: {:error, {:unsupported, detail}}
end
