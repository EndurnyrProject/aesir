defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen do
  @moduledoc """
  Final stage of the equip-script transpiler: NPC-transpiler AST -> refine-pure
  `EquipScript.program()` term.

  Walks the statement list produced by `Aesir.ZoneServer.Npc.Transpiler.Parser`
  (the shared rAthena front end) for an equip item's `Script`, consulting
  `BonusKeys` for supported destinations, and emits a plain-data bonus program.
  The emit is all-or-nothing (spec goal 5): the first out-of-vocabulary construct
  aborts the whole item with `{:error, {:unsupported, detail}}` and produces no
  program — the runtime never sees a partial one.

  ## Refine-variable inlining

  The `.@r = getrefine();` idiom is handled at transpile time. A top-level
  assignment to a `.@`-scoped variable binds its name to a compiled, refine-pure
  expression in a transpile-time environment; every later `.@r` use is
  substituted, so the emitted program is pure in a single input (refine) and the
  evaluator needs no variable environment. Later assignments shadow earlier ones.

  Assignments inside an `if` branch are rejected (`{:conditional_assignment, name}`):
  the value would depend on the branch taken, making inlining unsound. Branches are
  therefore walked with the environment read-only.

  ## Vocabulary

  - `{:assign, {:var, :local, name, :int}, ast}` at the top level — inline-bind,
    emit nothing.
  - `bonus bKey,amount` — `{:bonus, destination, expr}` when `bKey` resolves via
    `BonusKeys` (miss -> `{:unknown_bonus_key, key}`); any other command name and
    any other `bonus` shape (`bonus2`..`bonus5` parse as ordinary commands) is
    unsupported.
  - `if (cond) then [else]` — `{:if, cond, then, else}` when `cond` is a
    refine-pure boolean over comparisons / `&&` / `||`; a non-refine read such as
    `BaseLevel` is unsupported.
  - Expressions are refine-pure only: integer literals (including negated),
    `getrefine()` -> `:refine`, inlined `.@var`, and `+ - * /` arithmetic
    (`/` -> `:div`, matching C/Elixir truncating integer division). `rand(...)`
    and every other call are unsupported.

  A program that compiles to zero instructions (script was only assignments) yields
  `{:ok, []}`, which the importer stores as no `on_equip`.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  @type detail :: term()

  @arith_ops [:+, :-, :*, :/]
  @compare_ops [:>, :<, :>=, :<=, :==, :!=]
  @logic_ops [:&&, :||]

  @spec generate([tuple()]) ::
          {:ok, EquipScript.program()} | {:error, {:unsupported, detail()}}
  def generate(stmts) when is_list(stmts), do: reduce_top(unblock_all(stmts), %{}, [])

  @spec unblock_all([tuple()]) :: [tuple()]
  defp unblock_all(stmts), do: Enum.flat_map(stmts, &unblock/1)

  defp unblock({:block, stmts}), do: unblock_all(stmts)
  defp unblock(stmt), do: [stmt]

  @spec reduce_top([tuple()], %{String.t() => EquipScript.expr()}, [EquipScript.instr()]) ::
          {:ok, EquipScript.program()} | {:error, {:unsupported, detail()}}
  defp reduce_top([], _env, acc), do: {:ok, Enum.reverse(acc)}

  defp reduce_top([{:assign, {:var, :local, name, :int}, ast} | rest], env, acc) do
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
    stmts
    |> unblock_all()
    |> Enum.reduce_while({:ok, []}, fn stmt, {:ok, acc} ->
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
  defp branch_instr({:assign, {:var, :local, name, :int}, _ast}, _env),
    do: unsupported({:conditional_assignment, name})

  defp branch_instr(stmt, env), do: compile_instr(stmt, env)

  @spec compile_instr(tuple(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_instr({:cmd, "bonus", [{:name, key}, amount]}, env) do
    with {:ok, dest} <- destination(key),
         {:ok, expr} <- compile_expr(amount, env) do
      {:ok, {:bonus, dest, expr}}
    end
  end

  defp compile_instr({:cmd, "bonus", args}, _env), do: unsupported({:bonus_shape, args})

  defp compile_instr({:if, cond_expr, then_stmts, else_stmts}, env) do
    with {:ok, condition} <- compile_cond(cond_expr, env),
         {:ok, then_instrs} <- reduce_branch(then_stmts, env),
         {:ok, else_instrs} <- reduce_branch(else_stmts, env) do
      {:ok, {:if, condition, then_instrs, else_instrs}}
    end
  end

  defp compile_instr({:cmd, name, _args}, _env), do: unsupported({:unsupported_command, name})
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
  defp compile_expr({:int, n}, _env), do: {:ok, n}
  defp compile_expr({:neg, {:int, n}}, _env), do: {:ok, -n}

  defp compile_expr({:neg, ast}, env) do
    with {:ok, expr} <- compile_expr(ast, env), do: {:ok, {:-, 0, expr}}
  end

  defp compile_expr({:call, "getrefine", []}, _env), do: {:ok, :refine}

  defp compile_expr({:var, :local, name, :int}, env) do
    case Map.fetch(env, name) do
      {:ok, expr} -> {:ok, expr}
      :error -> unsupported({:unassigned_var, name})
    end
  end

  defp compile_expr({:bin, op, lhs, rhs}, env) when op in @arith_ops do
    with {:ok, l} <- compile_expr(lhs, env),
         {:ok, r} <- compile_expr(rhs, env) do
      {:ok, {arith_op(op), l, r}}
    end
  end

  defp compile_expr({:call, name, _args}, _env), do: unsupported({:unsupported_call, name})
  defp compile_expr(other, _env), do: unsupported({:expression, other})

  @spec compile_cond(term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.condition()} | {:error, {:unsupported, detail()}}
  defp compile_cond({:bin, op, lhs, rhs}, env) when op in @compare_ops do
    with {:ok, l} <- compile_expr(lhs, env),
         {:ok, r} <- compile_expr(rhs, env) do
      {:ok, {op, l, r}}
    end
  end

  defp compile_cond({:bin, op, lhs, rhs}, env) when op in @logic_ops do
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
