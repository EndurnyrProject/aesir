defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen do
  @moduledoc """
  Final stage of the equip-script transpiler: NPC-transpiler AST -> input-pure
  `EquipScript.program()` term.

  Walks the statement list produced by `Aesir.ZoneServer.Npc.Transpiler.Parser`
  (the shared rAthena front end) for an equip item's `Script`, consulting
  `BonusKeys` for supported destinations, and emits a plain-data bonus program.
  The emit is all-or-nothing (spec goal 5): the first out-of-vocabulary construct
  aborts the whole item with `{:error, {:unsupported, detail}}` and produces no
  program — the runtime never sees a partial one.

  ## Refine-variable inlining

  The `.@r = getrefine();` idiom is handled at transpile time. An assignment to
  a `.@`-scoped variable binds its name to a compiled, input-pure expression in
  a transpile-time environment; every later `.@r` use is substituted, so the
  emitted program is pure in the `EquipScript.inputs()` (refine, base level, job
  level) and the evaluator needs no variable environment. Later assignments
  shadow earlier ones. Compound assignment (`.@x += n`) is desugared by the
  front end to `.@x = .@x + n`, so it needs no special handling.

  Assignments inside an `if` branch are supported by folding the two branch
  environments back together at the join: a variable an `if` may have reassigned
  takes the branch-selecting ternary `cond ? then_value : else_value` at every
  later use, keeping the value input-pure even though it depended on the branch
  taken (`merge_envs/4`). A side that leaves the variable untouched reads the
  pre-`if` value, or `0` when the variable did not exist yet (rAthena's unset
  `.@var`). Bonuses emitted *inside* a branch already see that branch's evolving
  environment, so they inline the branch-local value directly.

  ## Vocabulary

  - `{:assign, {:var, :local, name, :int}, ast}` — inline-bind, emit nothing;
    inside an `if` branch it feeds `merge_envs/4` (see Refine-variable inlining).
  - `bonus bKey,amount` — `{:bonus, destination, expr}` when `bKey` resolves via
    `BonusKeys` (miss -> `{:unknown_bonus_key, key}`); any other command name and
    any other `bonus` shape is unsupported. Destinations carrying a
    `BonusKeys.destination_scale/1` factor emit the amount **expression**
    multiplied by it, so a refine-dependent amount converts units too.
  - `bonus bKey` (no argument) — rAthena's boolean-flag idiom
    (`bonus bUnbreakableWeapon;`): compiles exactly like `bonus bKey,1`.
  - `bonus bKey,CONST` — `{:set, destination, const}` for the constant-valued
    keys in `BonusKeys.value_schema/1` (`bAtkEle`, `bDefEle`), whose argument is
    an element constant rather than an amount. An unresolvable constant is
    `{:unresolved_param, detail}`.
  - `bonus bKey,PARAM` — `{:bonus, {family, param}, amount}` for the
    single-argument param-constant keys in `BonusKeys.flag_param_schema/1`
    (`bIgnoreDefRace,RC_Brute`), whose lone argument is a race/class constant and
    whose amount is the schema's fixed value (rAthena's full-effect 100). The
    param resolves exactly like a `bonus2` key.
  - `bonus2 bKey,param,amount` — `{:bonus, {family, param}, expr}` when `bKey`
    resolves via `BonusKeys.param_schema/1` and `param` resolves through
    `Resolver` according to the schema's param kind (race/element/size/class/status/race2
    via a `{:name, const}` constant, skill via a `{:name, const}` bare name, a
    `{:str, name}` quoted name — the corpus idiom `bonus2 bSkillAtk,"SM_BASH",n`
    — or an `{:int, id}` literal, and item via a bare `{:int, id}` kept verbatim).
    A key in `BonusKeys.pair_schema/1` instead takes two
    amounts and expands to TWO `{:bonus, dest, expr}` instructions, one per
    destination, each summing independently. A key in
    `BonusKeys.interval_family/1` (`bHPRegenRate`/`bHPLossRate`) instead carries
    an amount and a positive-integer interval; the interval becomes the
    destination param, emitting `{:bonus, {family, interval}, expr}` so
    equal-interval contributions sum. `RC_Boss` is a sentinel: on an `:addrace`/`:subrace`
    family it redirects to `:addclass`/`:subclass`; on any other family it is
    unsupported. A non-constant or unresolvable param is
    `{:unresolved_param, detail}`; any other shape is unsupported.
  - `bonus3 bKey,param,amount,flag` — for the keys in
    `BonusKeys.bonus3_flag_key?/1` (the sub-resist family and the on-hit
    status-infliction family), whose third argument is a trigger-condition flag
    rather than a value: the leading `param, amount` pair is identical to the
    key's `bonus2` form, so it resolves through the same param schema and the
    flag is dropped.
  - `bonus3 bAddMonsterDropItem,iid,r,n` — for the drop key in
    `BonusKeys.bonus3_drop_key?/1`, whose third argument is a genuine race param
    gating the bonus drop: emits a three-element `{family, item_id, race}`
    destination. Every other `bonus3` key, and `bonus4`/`bonus5`, parse as
    ordinary commands and stay unsupported.
  - `skill <skill id>,<level>{,<flag>}` — `{:grant_skill, id, expr}`, granting the
    wearer a castable skill at `level` while the item is worn. The skill id
    resolves like a `bonus2` skill param (constant name, quoted name, or literal
    id); the level is an ordinary amount expression; the optional trigger flag is
    dropped, since an equip grant is always the worn-item temporary skill.
  - `if (cond) then [else]` — `{:if, cond, then, else}` when `cond` is an
    input-pure boolean over comparisons / `&&` / `||`, or a job comparison:
    `Class`/`BaseClass`/`BaseJob` `==`/`!=` a `Job_*` constant compiles to
    `{:job_cmp, op, reader, job}`, resolved through `JobLineage` at runtime. A
    read outside this vocabulary, such as `eaclass()`, is unsupported.
  - Expressions are input-pure only: integer literals (including negated),
    `getrefine()` -> `:refine`, `BaseLevel` -> `:base_level`, `JobLevel` ->
    `:job_level`, inlined `.@var`, `+ - * /` arithmetic (`/` -> `:div`, matching
    C/Elixir truncating integer division), and the `cond ? a : b` ternary ->
    `{:ternary, cond, a, b}`, `getskilllv(<skill>)` -> `{:skill_lv, id}`
    (the wearer's learned level of a skill, resolved like a `bonus2` skill
    param), `readparam(<stat>)` -> `{:stat, atom}` (the wearer's base stat,
    for the base/trait stat constants only), and the pure two-argument integer
    combinators `min(a,b)`, `max(a,b)` and `pow(base,exp)` over the same
    input-pure operands, and a bare comparison used as an integer
    (`2+3*(getrefine()>5)`) -> `{:bool, cond}` (1/0). `rand(...)` and every other
    call are unsupported.

  A program that compiles to zero instructions (script was only assignments) yields
  `{:ok, []}`, which the importer stores as no `on_equip`.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

  @type detail :: term()
  @type dest :: atom() | {atom(), atom() | integer()} | {atom(), integer(), atom()}

  @arith_ops [:+, :-, :*, :/]
  @compare_ops [:>, :<, :>=, :<=, :==, :!=]
  @logic_ops [:&&, :||]

  @type env :: %{String.t() => EquipScript.expr()}

  @spec generate([tuple()]) ::
          {:ok, EquipScript.program()} | {:error, {:unsupported, detail()}}
  def generate(stmts) when is_list(stmts) do
    with {:ok, {instrs, _env}} <- reduce(unblock_all(stmts), %{}) do
      {:ok, instrs}
    end
  end

  @spec unblock_all([tuple()]) :: [tuple()]
  defp unblock_all(stmts), do: Enum.flat_map(stmts, &unblock/1)

  defp unblock({:block, stmts}), do: unblock_all(stmts)
  defp unblock(stmt), do: [stmt]

  # Threads the transpile-time variable environment through a statement list,
  # returning the emitted instructions and the resulting environment.
  @spec reduce([tuple()], env()) ::
          {:ok, {[EquipScript.instr()], env()}} | {:error, {:unsupported, detail()}}
  defp reduce(stmts, env) do
    Enum.reduce_while(stmts, {:ok, {[], env}}, fn stmt, {:ok, {acc, env}} ->
      case step(stmt, env) do
        {:ok, {instrs, env}} -> {:cont, {:ok, {acc ++ instrs, env}}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  # A `.@var` assignment binds an input-pure expression and emits nothing; an
  # `if` folds its branch environments back together (`merge_envs/4`); every
  # other statement compiles to instructions and leaves the environment as-is.
  @spec step(tuple(), env()) ::
          {:ok, {[EquipScript.instr()], env()}} | {:error, {:unsupported, detail()}}
  defp step({:assign, {:var, :local, name, :int}, ast}, env) do
    with {:ok, expr} <- compile_expr(ast, env) do
      {:ok, {[], Map.put(env, name, expr)}}
    end
  end

  defp step({:if, cond_expr, then_stmts, else_stmts}, env) do
    with {:ok, condition} <- compile_cond(cond_expr, env),
         {:ok, {then_instrs, then_env}} <- reduce(unblock_all(then_stmts), env),
         {:ok, {else_instrs, else_env}} <- reduce(unblock_all(else_stmts), env) do
      merged = merge_envs(env, condition, then_env, else_env)
      # An `if` whose branches emit nothing existed only to conditionally assign
      # a variable; that effect is already captured in `merged`, so it needs no
      # runtime instruction.
      instrs =
        if then_instrs == [] and else_instrs == [],
          do: [],
          else: [{:if, condition, then_instrs, else_instrs}]

      {:ok, {instrs, merged}}
    end
  end

  defp step(stmt, env) do
    with {:ok, instrs} <- compile_instrs(stmt, env) do
      {:ok, {instrs, env}}
    end
  end

  # Merges the two branch environments back into the pre-`if` environment: a
  # variable an `if` may have reassigned takes the branch-selecting ternary
  # `cond ? then_value : else_value` at every later use. An unset side reads the
  # pre-`if` value, or `0` when the variable did not exist yet. Variables neither
  # branch touched are left as they were, and a variable both branches set to the
  # same value skips the ternary.
  @spec merge_envs(env(), EquipScript.condition(), env(), env()) :: env()
  defp merge_envs(base_env, condition, then_env, else_env) do
    [then_env, else_env]
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
    |> Enum.filter(fn key ->
      Map.get(then_env, key) != Map.get(base_env, key) or
        Map.get(else_env, key) != Map.get(base_env, key)
    end)
    |> Enum.reduce(base_env, fn key, env ->
      then_value = branch_value(then_env, base_env, key)
      else_value = branch_value(else_env, base_env, key)

      merged =
        if then_value == else_value,
          do: then_value,
          else: {:ternary, condition, then_value, else_value}

      Map.put(env, key, merged)
    end)
  end

  @spec branch_value(env(), env(), String.t()) :: EquipScript.expr()
  defp branch_value(branch_env, base_env, key) do
    case Map.fetch(branch_env, key) do
      {:ok, value} -> value
      :error -> Map.get(base_env, key, 0)
    end
  end

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
      {:ok, schema} ->
        compile_value_bonus(schema, arg)

      :error ->
        case BonusKeys.flag_param_schema(key) do
          {:ok, schema} -> compile_flag_param_bonus(schema, arg)
          :error -> compile_amount_bonus(key, arg, env)
        end
    end
  end

  # The argument-less form is rAthena's boolean-flag idiom
  # (`bonus bUnbreakableWeapon;`) - the value is implicitly 1.
  defp compile_instr({:cmd, "bonus", [{:name, key}]}, env),
    do: compile_amount_bonus(key, {:int, 1}, env)

  defp compile_instr({:cmd, "bonus", args}, _env), do: unsupported({:bonus_shape, args})

  defp compile_instr({:cmd, "bonus2", [{:name, key}, first_arg, second_arg]}, env) do
    case BonusKeys.pair_schema(key) do
      {:ok, schema} ->
        compile_pair_bonus(schema, first_arg, second_arg, env)

      :error ->
        case BonusKeys.interval_family(key) do
          {:ok, family} -> compile_interval_bonus(family, first_arg, second_arg, env)
          :error -> compile_param_bonus(key, first_arg, second_arg, env)
        end
    end
  end

  defp compile_instr({:cmd, "bonus2", args}, _env), do: unsupported({:bonus_shape, args})

  # A `bonus3` key whose third argument is a trigger-condition flag has the same
  # leading `param, amount` pair as its `bonus2` form; it reuses that key's param
  # schema and drops the flag. Every other `bonus3` shape stays unsupported.
  defp compile_instr({:cmd, "bonus3", [{:name, key}, first_ast, second_ast, third_ast]}, env) do
    cond do
      BonusKeys.bonus3_drop_key?(key) ->
        compile_drop_bonus3(key, first_ast, second_ast, third_ast, env)

      BonusKeys.bonus3_flag_key?(key) ->
        compile_param_bonus(key, first_ast, second_ast, env)

      true ->
        unsupported({:unsupported_command, "bonus3"})
    end
  end

  # `skill <skill id>,<level>{,<flag>}` grants a castable skill while the item is
  # worn. The optional trigger flag is dropped: in an equip context the grant is
  # always the worn-item temporary skill. The level is an ordinary amount
  # expression and the skill id resolves like a `bonus2` skill param (a constant
  # name, a quoted name, or a literal id).
  defp compile_instr({:cmd, "skill", [skill_ast, level_ast]}, env),
    do: compile_grant_skill(skill_ast, level_ast, env)

  defp compile_instr({:cmd, "skill", [skill_ast, level_ast, _flag]}, env),
    do: compile_grant_skill(skill_ast, level_ast, env)

  defp compile_instr({:cmd, name, _args}, _env), do: unsupported({:unsupported_command, name})
  defp compile_instr(other, _env), do: unsupported({:statement, other})

  # `bonus3 bAddMonsterDropItem,iid,r,n` gates a bonus item drop on the slain
  # mob's race: the item id is a verbatim positive literal, the race a race
  # constant, and the chance an amount expression. Emits a three-element
  # `{family, item_id, race}` destination the loot roll reads only when the mob's
  # race matches. The `RC_Boss` sentinel is not a real race and is unsupported.
  @spec compile_drop_bonus3(String.t(), term(), term(), term(), %{
          String.t() => EquipScript.expr()
        }) :: {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_drop_bonus3(key, item_ast, race_ast, amount_ast, env) do
    with {:ok, %{family: family, param: :item}} <- param_schema(key),
         {:ok, item_id} <- drop_item_id(item_ast),
         {:ok, race} <- resolve_drop_race(race_ast),
         {:ok, expr} <- compile_expr(amount_ast, env) do
      {:ok, {:bonus, {family, item_id, race}, expr}}
    end
  end

  @spec drop_item_id(term()) :: {:ok, pos_integer()} | {:error, {:unsupported, detail()}}
  defp drop_item_id({:int, id}) when id > 0, do: {:ok, id}
  defp drop_item_id(other), do: unsupported({:unresolved_param, other})

  @spec resolve_drop_race(term()) :: {:ok, atom()} | {:error, {:unsupported, detail()}}
  defp resolve_drop_race({:name, const}) do
    case resolve(&Resolver.resolve_race/1, const) do
      {:ok, {:class, :boss}} -> unsupported({:unresolved_param, const})
      {:ok, race} -> {:ok, race}
      {:error, _} = error -> error
    end
  end

  defp resolve_drop_race(other), do: unsupported({:unresolved_param, other})

  @spec compile_grant_skill(term(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_grant_skill(skill_ast, level_ast, env) do
    with {:ok, id} <- resolve_skill_ref(skill_ast),
         {:ok, expr} <- compile_expr(level_ast, env) do
      {:ok, {:grant_skill, id, expr}}
    end
  end

  # Resolves a skill reference in the shapes the corpus uses for skill ids: a
  # constant name (`SM_BASH`), a quoted name (`"SM_BASH"`), or a literal id.
  @spec resolve_skill_ref(term()) :: {:ok, pos_integer()} | {:error, {:unsupported, detail()}}
  defp resolve_skill_ref({:name, const}), do: resolve(&Resolver.resolve_skill/1, const)
  defp resolve_skill_ref({:str, name}), do: resolve(&Resolver.resolve_skill/1, name)
  defp resolve_skill_ref({:int, id}), do: resolve(&Resolver.resolve_skill/1, id)
  defp resolve_skill_ref(other), do: unsupported({:unresolved_param, other})

  @spec compile_param_bonus(String.t(), term(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_param_bonus(key, param_ast, amount, env) do
    with {:ok, schema} <- param_schema(key),
         {:ok, dest} <- resolve_param(schema, param_ast),
         {:ok, expr} <- compile_expr(amount, env) do
      {:ok, {:bonus, dest, expr}}
    end
  end

  # A flag-param key carries its param in the lone `bonus` argument and a fixed
  # amount in its schema, so it resolves the param exactly like a `bonus2` key
  # and emits a single summing `:bonus` into the shared `{family, param}`
  # destination.
  @spec compile_flag_param_bonus(BonusKeys.flag_schema(), term()) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_flag_param_bonus(%{family: family, param: param, amount: amount}, param_ast) do
    with {:ok, dest} <- resolve_param(%{family: family, param: param}, param_ast) do
      {:ok, {:bonus, dest, amount}}
    end
  end

  # A periodic HP-regen/loss key `bonus2 bHPRegenRate,n,t` carries an amount and
  # an interval in milliseconds. The interval must be a positive integer literal;
  # it becomes the destination param so equal-interval contributions sum into one
  # `{family, interval}` entry the regen tick reads. A non-literal or non-positive
  # interval is unsupported.
  @spec compile_interval_bonus(atom(), term(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.instr()} | {:error, {:unsupported, detail()}}
  defp compile_interval_bonus(family, value_arg, {:int, interval}, env) when interval > 0 do
    with {:ok, expr} <- compile_expr(value_arg, env) do
      {:ok, {:bonus, {family, interval}, expr}}
    end
  end

  defp compile_interval_bonus(_family, _value_arg, interval_arg, _env),
    do: unsupported({:unresolved_param, interval_arg})

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

  @spec resolve_param(
          %{:family => atom(), :param => BonusKeys.param(), optional(atom()) => term()},
          term()
        ) :: {:ok, dest()} | {:error, {:unsupported, detail()}}
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

  defp resolve_param(%{family: family, param: :race2}, {:name, const}) do
    with {:ok, race2} <- resolve(&Resolver.resolve_race2/1, const), do: {:ok, {family, race2}}
  end

  # The `bAddItemHealRate` param is a bare item id kept verbatim - it is not
  # validated against the item catalog, which is not loaded during the import
  # mix task and which the runtime never needs to consult for this destination.
  defp resolve_param(%{family: family, param: :item}, {:int, id}) when id > 0,
    do: {:ok, {family, id}}

  # The `bAddDamageClass` param is a bare monster (mob database) id kept
  # verbatim, in the same spirit as the item-id param: it names a specific
  # monster the bonus applies against and is not validated against the mob
  # catalog at transpile time.
  defp resolve_param(%{family: family, param: :monster}, {:int, id}) when id > 0,
    do: {:ok, {family, id}}

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
  defp compile_expr({:name, "BaseLevel"}, _env), do: {:ok, :base_level}
  defp compile_expr({:name, "JobLevel"}, _env), do: {:ok, :job_level}

  defp compile_expr({:ternary, cond_ast, then_ast, else_ast}, env) do
    with {:ok, condition} <- compile_cond(cond_ast, env),
         {:ok, then_expr} <- compile_expr(then_ast, env),
         {:ok, else_expr} <- compile_expr(else_ast, env) do
      {:ok, {:ternary, condition, then_expr, else_expr}}
    end
  end

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

  # A comparison used where an integer is expected is rAthena's C idiom of a
  # boolean-as-int (`2+3*(getrefine()>5)`): it compiles to a `{:bool, cond}`
  # expression evaluating to 1/0.
  defp compile_expr({:bin, op, _lhs, _rhs} = ast, env) when op in @compare_ops do
    with {:ok, condition} <- compile_cond(ast, env), do: {:ok, {:bool, condition}}
  end

  # `getskilllv(<skill>)` reads the wearer's learned level of a skill; the id
  # resolves like a `bonus2` skill param and the runtime supplies the level from
  # its learned-skills input.
  defp compile_expr({:call, "getskilllv", [skill_ast]}, _env) do
    with {:ok, id} <- resolve_skill_ref(skill_ast), do: {:ok, {:skill_lv, id}}
  end

  # `readparam(<stat>)` reads the wearer's base stat; only the base/trait stat
  # constants (`bStr`, `bPow`, ...) are supported, resolving to the stat atom
  # the runtime feeds from its `:stats` input. Any other parameter is
  # unsupported.
  defp compile_expr({:call, "readparam", [{:name, const}]}, _env) do
    with {:ok, stat} <- resolve(&Resolver.resolve_stat_param/1, const), do: {:ok, {:stat, stat}}
  end

  # `pow`, `min` and `max` are pure two-argument integer combinators over the
  # input-pure vocabulary; they compile to the matching binary-op IR node.
  defp compile_expr({:call, "pow", [lhs, rhs]}, env), do: compile_math(:pow, lhs, rhs, env)
  defp compile_expr({:call, "min", [lhs, rhs]}, env), do: compile_math(:min, lhs, rhs, env)
  defp compile_expr({:call, "max", [lhs, rhs]}, env), do: compile_math(:max, lhs, rhs, env)

  defp compile_expr({:call, name, _args}, _env), do: unsupported({:unsupported_call, name})
  defp compile_expr(other, _env), do: unsupported({:expression, other})

  @spec compile_math(:min | :max | :pow, term(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.expr()} | {:error, {:unsupported, detail()}}
  defp compile_math(op, lhs, rhs, env) do
    with {:ok, l} <- compile_expr(lhs, env),
         {:ok, r} <- compile_expr(rhs, env) do
      {:ok, {op, l, r}}
    end
  end

  @spec compile_cond(term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.condition()} | {:error, {:unsupported, detail()}}
  # An equality/inequality between a job reader (`Class`/`BaseClass`/`BaseJob`)
  # and a `Job_*` constant compiles to a `{:job_cmp, ...}` condition resolved
  # through `JobLineage` at runtime; anything else is an ordinary numeric compare.
  defp compile_cond({:bin, op, lhs, rhs}, env) when op in [:==, :!=] do
    case job_operands(lhs, rhs) do
      {:ok, reader, class_sym} ->
        with {:ok, job} <- resolve(&Resolver.resolve_class/1, class_sym),
             do: {:ok, {:job_cmp, op, reader, job}}

      :not_job ->
        compile_binary_cond(op, lhs, rhs, env)
    end
  end

  defp compile_cond({:bin, op, lhs, rhs}, env) when op in @compare_ops do
    compile_binary_cond(op, lhs, rhs, env)
  end

  defp compile_cond({:bin, op, lhs, rhs}, env) when op in @logic_ops do
    with {:ok, l} <- compile_cond(lhs, env),
         {:ok, r} <- compile_cond(rhs, env) do
      {:ok, {logic_op(op), l, r}}
    end
  end

  defp compile_cond(other, _env), do: unsupported({:condition, other})

  @spec compile_binary_cond(atom(), term(), term(), %{String.t() => EquipScript.expr()}) ::
          {:ok, EquipScript.condition()} | {:error, {:unsupported, detail()}}
  defp compile_binary_cond(op, lhs, rhs, env) do
    with {:ok, l} <- compile_expr(lhs, env),
         {:ok, r} <- compile_expr(rhs, env) do
      {:ok, {op, l, r}}
    end
  end

  # Classifies an `==`/`!=` operand pair as a job comparison when one side is a
  # job reader name and the other a `Job_*` constant (either order); otherwise
  # the pair is an ordinary numeric comparison.
  @spec job_operands(term(), term()) :: {:ok, atom(), String.t()} | :not_job
  defp job_operands({:name, a}, {:name, b}) do
    case {job_reader(a), job_reader(b)} do
      {reader, nil} when not is_nil(reader) -> job_pair(reader, b)
      {nil, reader} when not is_nil(reader) -> job_pair(reader, a)
      _ -> :not_job
    end
  end

  defp job_operands(_lhs, _rhs), do: :not_job

  defp job_pair(reader, const) do
    if job_const?(const), do: {:ok, reader, const}, else: :not_job
  end

  @spec job_reader(String.t()) :: atom() | nil
  defp job_reader(name) do
    case String.downcase(name) do
      "class" -> :class
      "baseclass" -> :base_class
      "basejob" -> :base_job
      _ -> nil
    end
  end

  @spec job_const?(String.t()) :: boolean()
  defp job_const?(name), do: String.match?(name, ~r/^job_/i)

  @spec arith_op(atom()) :: EquipScript.arith_op()
  defp arith_op(:/), do: :div
  defp arith_op(op), do: op

  @spec logic_op(atom()) :: EquipScript.logic_op()
  defp logic_op(:&&), do: :and
  defp logic_op(:||), do: :or

  @spec unsupported(detail()) :: {:error, {:unsupported, detail()}}
  defp unsupported(detail), do: {:error, {:unsupported, detail}}
end
