defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Codegen do
  @moduledoc """
  Final stage of the rAthena item-script transpiler: NPC-transpiler AST ->
  Aesir `on_use` DSL source string.

  Walks the statement list produced by `Aesir.ZoneServer.Npc.Transpiler.Parser`
  (the shared rAthena front end), consulting `CommandSet` (supported
  commands/reads) and `Resolver` (rAthena constants -> Aesir values), and emits
  a single Elixir expression that `ScriptCompiler` compiles unchanged. The emit
  is all-or-nothing: the moment any command, read, or construct falls outside
  the supported subset it returns `{:error, {:unsupported, detail}}` and
  produces no source.

  ## ctx threading

  Every emitted DSL op takes `ctx` first and returns `ctx`. The body is one
  expression that evaluates to the threaded `ctx`:

  - a single statement is the bare call, e.g. `heal(ctx, hp: 45)`;
  - a single `if` is the bare `if/else` expression, each branch returning `ctx`;
  - multiple statements rebind `ctx` line by line and return it:

        ctx = heal(ctx, hp: 45)
        ctx = sc_start(ctx, :sc_blessing, 60000, 10)
        ctx

  An empty `else` branch emits `ctx`, so `if` returns `ctx` either way.

  ## `rand`

  rAthena `rand(a, b)` is inclusive `a..b` and `rand(n)` is `0..n-1`. In a `heal`
  amount it becomes a range literal (`heal` rolls within it); anywhere else it
  becomes `Enum.random/1`. No randomness happens at transpile time — same script,
  same string.

  ## `warp`

  `warp "map",x,y` emits `warp(ctx, "map", x, y)`. The two string-target forms
  `warp "Random",0,0` (fly wing) and `warp "SavePoint",0,0` (butterfly wing) emit
  the one-arg DSL atom form `warp(ctx, :random)` / `warp(ctx, :save_point)` via
  `CommandSet.warp_target/1`.

  ## `sc_start`

  The base `sc_start type,ticks,val1` form emits `sc_start(ctx, status, ticks,
  val1)` via the standard `CommandSet` rule. rAthena's optional `rate` (out of
  10000) and `flag` arguments — `sc_start type,ticks,val1,rate{,flag}`, common on
  foods that carry a chance to inflict a negative status — are handled here: the
  `rate` becomes a runtime `Enum.random(1..10_000) <= rate` guard around the base
  call, and the `flag` bitmask is dropped (no sc-flag is modelled). A `rate` of
  `10000` (always) collapses back to the plain call. The six-arg GID-targeted form
  is unsupported.

  ## Char variable increments

  `Var++;` / `Var--;` on a bare permanent char variable (e.g. `RouletteGold++`,
  the Roulette-coin currency) arrive desugared by the parser as the
  self-referencing assignment `{:assign, {:name, v}, {:bin, op, {:name, v},
  {:int, 1}}}` and emit a `set_char_var`/`get_char_var` round-trip,
  `set_char_var(ctx, :Var, get_char_var(ctx, :Var, 0) + 1)`, using the verbatim
  rAthena name as the atom key — matching the NPC transpiler's char-var
  convention.

  ## Announce flags

  A `bc_*` broadcast-flag argument may be a single constant, an integer literal
  (decimal or hex), or a `|` union (`bc_all|bc_blue`); unions are folded to
  their integer value at transpile time via `Flags`.
  """

  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CommandSet
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

  @type ast_stmt :: tuple()
  @type detail :: term()

  @binary_ops [:+, :-, :*, :/, :>, :<, :>=, :<=, :==, :!=]
  @logic_ops [:&&, :||]

  @spec generate([ast_stmt()]) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  def generate(stmts) when is_list(stmts), do: render_stmts(stmts)

  @spec render_stmts([ast_stmt()]) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_stmts(stmts) do
    case Enum.flat_map(stmts, &unblock/1) do
      [] -> {:ok, "ctx"}
      [stmt] -> render_stmt(stmt)
      flat -> render_block(flat)
    end
  end

  defp render_block(stmts) do
    with {:ok, exprs} <- map_ok(stmts, &render_stmt/1) do
      body = exprs |> Enum.map(&"ctx = #{&1}") |> Kernel.++(["ctx"]) |> Enum.join("\n")
      {:ok, body}
    end
  end

  @spec unblock(ast_stmt()) :: [ast_stmt()]
  defp unblock({:block, stmts}), do: Enum.flat_map(stmts, &unblock/1)
  defp unblock(stmt), do: [stmt]

  @spec render_stmt(ast_stmt()) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_stmt({:cmd, name, args}), do: render_command(name, args)

  defp render_stmt({:assign, {:name, name}, {:bin, op, {:name, name}, {:int, 1}}})
       when op in [:+, :-] do
    key = inspect(String.to_atom(name))
    {:ok, "set_char_var(ctx, #{key}, get_char_var(ctx, #{key}, 0) #{op} 1)"}
  end

  defp render_stmt({:if, cond_expr, then_stmts, else_stmts}) do
    with {:ok, cond_src} <- render_expr(cond_expr),
         {:ok, then_src} <- render_stmts(then_stmts),
         {:ok, else_src} <- render_stmts(else_stmts) do
      {:ok, "if #{cond_src} do\n#{indent(then_src)}\nelse\n#{indent(else_src)}\nend"}
    end
  end

  defp render_stmt(other), do: unsupported({:statement, other})

  @spec render_command(String.t(), [term()]) ::
          {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_command("warp", [{:str, target}, _x, _y] = args) do
    case CommandSet.warp_target(target) do
      {:ok, dsl_atom} -> {:ok, "warp(ctx, #{dsl_atom})"}
      :error -> render_known_command("warp", args)
    end
  end

  defp render_command("sc_start", [status, ticks, val1, rate | flag])
       when flag == [] or (is_list(flag) and length(flag) == 1) do
    with {:ok, s} <- render_arg(:status, status),
         {:ok, t} <- render_arg(:int, ticks),
         {:ok, v} <- render_arg(:int, val1),
         {:ok, r} <- render_arg(:int, rate) do
      render_sc_start_rate(s, t, v, r)
    end
  end

  defp render_command(name, args), do: render_known_command(name, args)

  @spec render_sc_start_rate(String.t(), String.t(), String.t(), String.t()) :: {:ok, String.t()}
  defp render_sc_start_rate(status, ticks, val, "10000"),
    do: {:ok, "sc_start(ctx, #{status}, #{ticks}, #{val})"}

  defp render_sc_start_rate(status, ticks, val, rate),
    do:
      {:ok,
       "if(Enum.random(1..10_000) <= #{rate}, do: sc_start(ctx, #{status}, #{ticks}, #{val}), else: ctx)"}

  @spec render_known_command(String.t(), [term()]) ::
          {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_known_command(name, args) do
    case CommandSet.command(name) do
      {:ok, rule} -> render_rule(rule, args)
      :error -> unsupported(name)
    end
  end

  defp render_rule(%{shape: :heal, dsl: dsl}, [hp_expr, sp_expr]) do
    with {:ok, hp_opt} <- heal_opt("hp", hp_expr),
         {:ok, sp_opt} <- heal_opt("sp", sp_expr) do
      case Enum.reject([hp_opt, sp_opt], &is_nil/1) do
        [] -> {:ok, "#{dsl}(ctx)"}
        opts -> {:ok, "#{dsl}(ctx, #{Enum.join(opts, ", ")})"}
      end
    end
  end

  defp render_rule(%{shape: :itemskill, dsl: dsl}, [skill_expr, level_expr]) do
    with {:ok, skill} <- render_arg(:skill, skill_expr),
         {:ok, level} <- render_arg(:int, level_expr) do
      {:ok, "#{dsl}(ctx, #{skill}, level: #{level})"}
    end
  end

  defp render_rule(%{shape: :call, dsl: dsl, args: types}, args)
       when length(types) == length(args) do
    with {:ok, rendered} <- map_ok(Enum.zip(types, args), fn {t, a} -> render_arg(t, a) end) do
      case rendered do
        [] -> {:ok, "#{dsl}(ctx)"}
        _args -> {:ok, "#{dsl}(ctx, #{Enum.join(rendered, ", ")})"}
      end
    end
  end

  defp render_rule(%{shape: :item_group_optional, dsl: dsl, args: types}, args) do
    with {:ok, rendered} <- render_item_group_optional(args, types) do
      {:ok, "#{dsl}(ctx, #{Enum.join(rendered, ", ")})"}
    end
  end

  defp render_rule(%{shape: :announce, dsl: dsl, fixed: fixed}, args)
       when length(args) >= fixed do
    kept = Enum.take(args, fixed + 1)

    with {:ok, rendered} <-
           map_ok(Enum.with_index(kept), fn {arg, i} -> render_announce_arg(arg, i, fixed) end) do
      {:ok, "#{dsl}(ctx, #{Enum.join(rendered, ", ")})"}
    end
  end

  defp render_rule(rule, args), do: unsupported({:arity, rule.dsl, args})

  defp render_item_group_optional(args, types) when length(args) == length(types) do
    types
    |> render_args(args)
    |> append_default_subgroup()
  end

  defp render_item_group_optional(args, types) when length(args) == length(types) + 1,
    do: render_args(types ++ [:int], args)

  defp render_item_group_optional(args, _types),
    do: unsupported({:arity, :item_group_optional, args})

  defp render_args(types, args),
    do: map_ok(Enum.zip(types, args), fn {type, arg} -> render_arg(type, arg) end)

  defp append_default_subgroup({:ok, rendered}), do: {:ok, rendered ++ ["0"]}
  defp append_default_subgroup(error), do: error

  @spec render_announce_arg(term(), non_neg_integer(), pos_integer()) ::
          {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_announce_arg(arg, i, fixed) when i == fixed - 1, do: render_arg(:flag, arg)
  defp render_announce_arg(arg, _i, _fixed), do: render_expr(arg)

  @spec heal_opt(String.t(), term()) ::
          {:ok, String.t() | nil} | {:error, {:unsupported, detail()}}
  defp heal_opt(_label, {:int, 0}), do: {:ok, nil}
  defp heal_opt(label, {:int, n}), do: {:ok, "#{label}: #{n}"}
  defp heal_opt(label, {:neg, {:int, n}}), do: {:ok, "#{label}: #{-n}"}

  defp heal_opt(label, {:call, "rand", [{:int, a}, {:int, b}]}),
    do: {:ok, "#{label}: #{a}..#{b}"}

  defp heal_opt(label, {:call, "rand", [{:int, n}]}),
    do: {:ok, "#{label}: 0..#{n - 1}"}

  defp heal_opt(_label, other), do: unsupported({:heal_amount, other})

  @spec render_arg(atom(), term()) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_arg(:int, {:int, n}), do: {:ok, Integer.to_string(n)}
  defp render_arg(:int, {:neg, {:int, n}}), do: {:ok, Integer.to_string(-n)}
  defp render_arg(:int, other), do: unsupported({:expected_literal_int, other})

  defp render_arg(:flag, expr) do
    with {:ok, value} <- flag_value(expr), do: {:ok, Integer.to_string(value)}
  end

  defp render_arg(:string, {:str, s}), do: {:ok, inspect(s)}
  defp render_arg(:string, other), do: unsupported({:expected_string, other})

  defp render_arg(:status, {:name, name}),
    do: resolved(Resolver.resolve_status(name), &inspect/1)

  defp render_arg(:effect, {:name, name}),
    do: resolved(Resolver.resolve_effect(name), &inspect/1)

  defp render_arg(:item, {:name, name}),
    do: resolved(Resolver.resolve_item(name), &Integer.to_string/1)

  defp render_arg(:item, {:int, id}),
    do: resolved(Resolver.resolve_item(id), &Integer.to_string/1)

  defp render_arg(:item, expr), do: render_expr(expr)

  defp render_arg(:item_group, {:name, name}),
    do: resolved(Resolver.resolve_item_group(name), &inspect/1)

  defp render_arg(:skill, {:name, name}),
    do: resolved(Resolver.resolve_skill(name), &Integer.to_string/1)

  # A skill argument is written as a quoted name just as often as a bare
  # constant ("ITEM_ENCHANTARMS"); both resolve against the same catalog.
  defp render_arg(:skill, {:str, name}),
    do: resolved(Resolver.resolve_skill(name), &Integer.to_string/1)

  defp render_arg(:skill, {:int, id}),
    do: resolved(Resolver.resolve_skill(id), &Integer.to_string/1)

  defp render_arg(type, other), do: unsupported({type, other})

  @spec flag_value(term()) :: {:ok, integer()} | {:error, {:unsupported, detail()}}
  defp flag_value({:int, n}), do: {:ok, n}

  defp flag_value({:name, name} = expr) do
    if String.starts_with?(String.downcase(name), "bc_") do
      case Flags.value(name) do
        {:ok, value} -> {:ok, value}
        :error -> unsupported({:unknown_const, name})
      end
    else
      unsupported({:expected_flag, expr})
    end
  end

  defp flag_value({:bin, :|, lhs, rhs}) do
    with {:ok, l} <- flag_value(lhs),
         {:ok, r} <- flag_value(rhs) do
      {:ok, Bitwise.bor(l, r)}
    end
  end

  defp flag_value(other), do: unsupported({:expected_flag, other})

  @spec render_expr(term()) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_expr({:int, n}), do: {:ok, Integer.to_string(n)}
  defp render_expr({:str, s}), do: {:ok, inspect(s)}
  defp render_expr({:neg, {:int, n}}), do: {:ok, Integer.to_string(-n)}

  defp render_expr({:neg, expr}) do
    with {:ok, src} <- render_expr(expr), do: {:ok, "(0 - #{src})"}
  end

  defp render_expr({:name, name}) do
    case CommandSet.read(name) do
      {:ok, dsl} -> {:ok, "#{dsl}(ctx)"}
      :error -> render_const(name)
    end
  end

  defp render_expr({:call, "rand", [a, b]}) do
    with {:ok, lo} <- render_expr(a), {:ok, hi} <- render_expr(b) do
      {:ok, "Enum.random(#{lo}..#{hi})"}
    end
  end

  defp render_expr({:call, "rand", [n]}) do
    with {:ok, src} <- render_expr(n), do: {:ok, "Enum.random(0..(#{src} - 1))"}
  end

  defp render_expr({:call, "countitem", [id]}),
    do: resolved(resolve_item_expr(id), &"count_item(ctx, #{&1})")

  defp render_expr({:call, name, args}) do
    case CommandSet.call_read(name) do
      {:ok, %{shape: :item_group_optional, dsl: dsl, args: types}} ->
        with {:ok, rendered} <- render_item_group_optional(args, types) do
          {:ok, "#{dsl}(ctx, #{Enum.join(rendered, ", ")})"}
        end

      :error ->
        unsupported({:unknown_call, name})
    end
  end

  defp render_expr({:bin, op, lhs, rhs}) when op in @binary_ops do
    with {:ok, l} <- render_expr(lhs), {:ok, r} <- render_expr(rhs), do: {:ok, binop(op, l, r)}
  end

  defp render_expr({:bin, op, lhs, rhs}) when op in @logic_ops do
    with {:ok, l} <- render_expr(lhs), {:ok, r} <- render_expr(rhs) do
      {:ok, "(#{l} #{op} #{r})"}
    end
  end

  defp render_expr(other), do: unsupported({:expression, other})

  @spec render_const(String.t()) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp render_const("SC_" <> _ = name), do: resolved(Resolver.resolve_status(name), &inspect/1)
  defp render_const("Ele_" <> _ = name), do: resolved(Resolver.resolve_element(name), &inspect/1)
  defp render_const("Job_" <> _ = name), do: resolved(Resolver.resolve_class(name), &inspect/1)

  defp render_const("bc_" <> _ = name) do
    with {:ok, value} <- flag_value({:name, name}), do: {:ok, Integer.to_string(value)}
  end

  defp render_const(name), do: unsupported({:unknown_const, name})

  defp resolve_item_expr({:int, id}), do: Resolver.resolve_item(id)
  defp resolve_item_expr({:name, name}), do: Resolver.resolve_item(name)
  defp resolve_item_expr(other), do: {:error, {:unknown_symbol, inspect(other)}}

  @spec binop(atom(), String.t(), String.t()) :: String.t()
  defp binop(:/, l, r), do: "div(#{l}, #{r})"
  defp binop(op, l, r), do: "(#{l} #{op} #{r})"

  @spec resolved(
          {:ok, term()} | {:error, {:unknown_symbol, String.t()}},
          (term() -> String.t())
        ) :: {:ok, String.t()} | {:error, {:unsupported, detail()}}
  defp resolved({:ok, value}, render), do: {:ok, render.(value)}

  defp resolved({:error, {:unknown_symbol, sym}}, _render),
    do: unsupported({:unknown_symbol, sym})

  @spec map_ok([term()], (term() -> {:ok, term()} | {:error, term()})) ::
          {:ok, [term()]} | {:error, term()}
  defp map_ok(items, fun) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  @spec indent(String.t()) :: String.t()
  defp indent(source) do
    source
    |> String.split("\n")
    |> Enum.map_join("\n", &"  #{&1}")
  end

  @spec unsupported(detail()) :: {:error, {:unsupported, detail()}}
  defp unsupported(detail), do: {:error, {:unsupported, detail}}
end
