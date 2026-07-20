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
    any other `bonus` shape is unsupported. Destinations carrying a
    `BonusKeys.destination_scale/1` factor emit the amount **expression**
    multiplied by it, so a refine-dependent amount converts units too.
  - `bonus bKey,CONST` — `{:set, destination, const}` for the constant-valued
    keys in `BonusKeys.value_schema/1` (`bAtkEle`), whose argument is an element
    constant rather than an amount. An unresolvable constant is
    `{:unresolved_param, detail}`.
  - `bonus2 bKey,param,amount` — `{:bonus, {family, param}, expr}` when `bKey`
    resolves via `BonusKeys.param_schema/1` and `param` resolves through
    `Resolver` according to the schema's param kind (race/element/size/class/status
    via a `{:name, const}` constant, skill via a `{:name, const}` bare name, a
    `{:str, name}` quoted name — the corpus idiom `bonus2 bSkillAtk,"SM_BASH",n`
    — or an `{:int, id}` literal). A key in `BonusKeys.pair_schema/1` instead takes two
    amounts and expands to TWO `{:bonus, dest, expr}` instructions, one per
    destination, each summing independently. `RC_Boss` is a sentinel: on an `:addrace`/`:subrace`
    family it redirects to `:addclass`/`:subclass`; on any other family it is
    unsupported. A non-constant or unresolvable param is
    `{:unresolved_param, detail}`; any other shape is unsupported.
    `bonus3`..`bonus5` parse as ordinary commands and stay unsupported.
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
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

  @type detail :: term()
  @type dest :: atom() | {atom(), atom() | integer()}

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
    with {:ok, instrs} <- compile_instrs(stmt, env) do
      reduce_top(rest, env, Enum.reverse(instrs) ++ acc)
    end
  end

  @spec reduce_branch([tuple()], %{String.t() => EquipScript.expr()}) ::
          {:ok, [EquipScript.instr()]} | {:error, {:unsupported, detail()}}
  defp reduce_branch(stmts, env) do
    stmts
    |> unblock_all()
    |> Enum.reduce_while({:ok, []}, fn stmt, {:ok, acc} ->
      case branch_instr(stmt, env) do
        {:ok, instrs} -> {:cont, {:ok, Enum.reverse(instrs) ++ acc}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  @spec branch_instr(tuple(), %{String.t() => EquipScript.expr()}) ::
          {:ok, [EquipScript.instr()]} | {:error, {:unsupported, detail()}}
  defp branch_instr({:assign, {:var, :local, name, :int}, _ast}, _env),
    do: unsupported({:conditional_assignment, name})

  defp branch_instr(stmt, env), do: compile_instrs(stmt, env)

  # A statement normally compiles to exactly one instruction; pair keys expand
  # to two. Normalizing here keeps both fold points list-shaped without every
  # `compile_instr/2` clause having to wrap itself.
  @spec compile_instrs(tuple(), %{String.t() => EquipScript.expr()}) ::
          {:ok, [EquipScript.instr()]} | {:error, {:unsupported, detail()}}
  defp compile_instrs(stmt, env) do
    case compile_instr(stmt, env) do
      {:ok, instrs} when is_list(instrs) -> {:ok, instrs}
      {:ok, instr} -> {:ok, [instr]}
      {:error, _} = error -> error
    end
  end

  @spec compile_instr(tuple(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr() | [EquipScript.instr()]}
          | {:error, {:unsupported, detail()}}
  defp compile_instr({:cmd, "bonus", [{:name, key}, arg]}, env) do
    case BonusKeys.value_schema(key) do
      {:ok, schema} -> compile_value_bonus(schema, arg)
      :error -> compile_amount_bonus(key, arg, env)
    end
  end

  defp compile_instr({:cmd, "bonus", args}, _env), do: unsupported({:bonus_shape, args})

  defp compile_instr({:cmd, "bonus2", [{:name, key}, first_arg, second_arg]}, env) do
    case BonusKeys.pair_schema(key) do
      {:ok, schema} -> compile_pair_bonus(schema, first_arg, second_arg, env)
      :error -> compile_param_bonus(key, first_arg, second_arg, env)
    end
  end

  defp compile_instr({:cmd, "bonus2", args}, _env), do: unsupported({:bonus_shape, args})

  defp compile_instr({:if, cond_expr, then_stmts, else_stmts}, env) do
    with {:ok, condition} <- compile_cond(cond_expr, env),
         {:ok, then_instrs} <- reduce_branch(then_stmts, env),
         {:ok, else_instrs} <- reduce_branch(else_stmts, env) do
      {:ok, {:if, condition, then_instrs, else_instrs}}
    end
  end

  defp compile_instr({:cmd, name, _args}, _env), do: unsupported({:unsupported_command, name})
  defp compile_instr(other, _env), do: unsupported({:statement, other})

  @spec compile_param_bonus(String.t(), term(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_param_bonus(key, param_ast, amount, env) do
    with {:ok, schema} <- param_schema(key),
         {:ok, dest} <- resolve_param(schema, param_ast),
         {:ok, expr} <- compile_expr(amount, env) do
      {:ok, {:bonus, dest, expr}}
    end
  end

  # Both arguments of a pair key are amounts summing into a destination of their
  # own, so the key expands to two independent `:bonus` instructions rather than
  # an IR shape of its own.
  @spec compile_pair_bonus(
          BonusKeys.pair_schema(),
          term(),
          term(),
          %{String.t() => EquipScript.expr()}
        ) :: {:ok, [EquipScript.instr()]} | {:error, {:unsupported, detail()}}
  defp compile_pair_bonus(%{first: first_dest, second: second_dest}, first_arg, second_arg, env) do
    with {:ok, first_expr} <- compile_expr(first_arg, env),
         {:ok, second_expr} <- compile_expr(second_arg, env) do
      {:ok,
       [
         {:bonus, first_dest, scale(first_dest, first_expr)},
         {:bonus, second_dest, scale(second_dest, second_expr)}
       ]}
    end
  end

  @spec compile_amount_bonus(String.t(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_amount_bonus(key, amount, env) do
    with {:ok, dest} <- destination(key),
         {:ok, expr} <- compile_expr(amount, env) do
      {:ok, {:bonus, dest, scale(dest, expr)}}
    end
  end

  # Destinations whose consumer reads finer units than the script writes carry a
  # `BonusKeys.destination_scale/1` factor. Scaling the whole expression (rather
  # than a literal) keeps refine-dependent amounts correct.
  @spec scale(atom(), EquipScript.expr()) :: EquipScript.expr()
  defp scale(dest, expr) do
    case BonusKeys.destination_scale(dest) do
      1 -> expr
      factor when is_integer(expr) -> expr * factor
      factor -> {:*, expr, factor}
    end
  end

  @spec compile_value_bonus(BonusKeys.value_schema(), term()) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  # `:all` is a summing-family param (`bSubEle,Ele_All`); as a value it names
  # no single element, so it cannot be `:set`.
  defp compile_value_bonus(%{dest: dest, param: :element}, {:name, const}) do
    case resolve(&Resolver.resolve_element/1, const) do
      {:ok, :all} -> unsupported({:unresolved_param, const})
      {:ok, element} -> {:ok, {:set, dest, element}}
      {:error, _} = error -> error
    end
  end

  defp compile_value_bonus(_schema, arg), do: unsupported({:unresolved_param, arg})

  @spec destination(String.t()) :: {:ok, atom()} | {:error, {:unsupported, detail()}}
  defp destination(key) do
    case BonusKeys.destination(key) do
      {:ok, dest} -> {:ok, dest}
      :error -> unsupported({:unknown_bonus_key, key})
    end
  end

  @spec param_schema(String.t()) ::
          {:ok, BonusKeys.param_schema()} | {:error, {:unsupported, detail()}}
  defp param_schema(key) do
    case BonusKeys.param_schema(key) do
      {:ok, schema} -> {:ok, schema}
      :error -> unsupported({:unknown_bonus_key, key})
    end
  end

  @spec resolve_param(BonusKeys.param_schema(), term()) ::
          {:ok, dest()} | {:error, {:unsupported, detail()}}
  defp resolve_param(%{family: family, param: :race}, {:name, const}) do
    with {:ok, race} <- resolve(&Resolver.resolve_race/1, const), do: race_dest(family, race)
  end

  defp resolve_param(%{family: family, param: :element}, {:name, const}) do
    with {:ok, element} <- resolve(&Resolver.resolve_element/1, const),
         do: {:ok, {family, element}}
  end

  defp resolve_param(%{family: family, param: :size}, {:name, const}) do
    with {:ok, size} <- resolve(&Resolver.resolve_size/1, const), do: {:ok, {family, size}}
  end

  defp resolve_param(%{family: family, param: :class}, {:name, const}) do
    with {:ok, class} <- resolve(&Resolver.resolve_mob_class/1, const), do: {:ok, {family, class}}
  end

  defp resolve_param(%{family: family, param: :skill}, {:name, const}) do
    with {:ok, id} <- resolve(&Resolver.resolve_skill/1, const), do: {:ok, {family, id}}
  end

  defp resolve_param(%{family: family, param: :skill}, {:str, name}) do
    with {:ok, id} <- resolve(&Resolver.resolve_skill/1, name), do: {:ok, {family, id}}
  end

  defp resolve_param(%{family: family, param: :skill}, {:int, id}) do
    with {:ok, id} <- resolve(&Resolver.resolve_skill/1, id), do: {:ok, {family, id}}
  end

  defp resolve_param(%{family: family, param: :status}, {:name, const}) do
    with {:ok, status} <- resolve(&Resolver.resolve_eff/1, const), do: {:ok, {family, status}}
  end

  defp resolve_param(_schema, param_ast), do: unsupported({:unresolved_param, param_ast})

  @spec race_dest(atom(), atom() | {:class, :boss}) ::
          {:ok, dest()} | {:error, {:unsupported, detail()}}
  defp race_dest(family, {:class, :boss}) when family in [:addrace, :subrace],
    do: {:ok, {class_family(family), :boss}}

  defp race_dest(_family, {:class, :boss} = sentinel),
    do: unsupported({:unresolved_param, sentinel})

  defp race_dest(family, race), do: {:ok, {family, race}}

  @spec class_family(:addrace | :subrace) :: :addclass | :subclass
  defp class_family(:addrace), do: :addclass
  defp class_family(:subrace), do: :subclass

  @spec resolve((term() -> {:ok, term()} | Resolver.error()), term()) ::
          {:ok, term()} | {:error, {:unsupported, detail()}}
  defp resolve(resolver_fun, symbol) do
    case resolver_fun.(symbol) do
      {:ok, value} -> {:ok, value}
      {:error, {:unknown_symbol, s}} -> unsupported({:unresolved_param, s})
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
