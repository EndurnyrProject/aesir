defmodule Aesir.ZoneServer.Npc.Transpiler.Analyzer do
  @moduledoc """
  Semantic pass over a parsed script body.

  Walks the AST once and returns everything the codegen needs to emit a
  module:

  - `labels` — every label in source order (fall-through chaining follows it)
  - `jump_targets` — labels reached by `goto` or `menu`, emitted as functions
  - `callsub_targets` — labels called by `callsub`, emitted as subroutines
    returning `{ctx, value}`

  rAthena resolves label references case-insensitively, so both target sets
  hold downcased names; `labels` keeps the declared spelling.
  - `events` — `On*` labels (`OnInit`, `OnTouch`, `OnTimer…`)
  - `assigned_names` — bare identifiers the script writes (assignment or
    `input`); these are permanent char vars, distinguishing them from
    constants and engine reads
  - `local_functions` — script-local `function Name { … }` definitions
  - `stubs` — buildins with no Aesir mapping, with call-site counts (the
    report's implementation priority list)

  Variable scope itself needs no analysis: the lexer already tags every
  prefixed variable with its scope, and a bare name is a char var exactly when
  it is not an engine read (`CommandMap.read/1`), not a resolvable constant,
  and not a label/function name.
  """

  alias Aesir.ZoneServer.Npc.Transpiler.CommandMap

  # Statements and expression calls the codegen shapes directly.
  @native_cmds ~w(mes next close close2 end select prompt input menu setarray
                  callsub callfunc getarg rand)

  @type analysis :: %{
          labels: [String.t()],
          jump_targets: MapSet.t(String.t()),
          callsub_targets: MapSet.t(String.t()),
          events: [String.t()],
          assigned_names: MapSet.t(String.t()),
          local_functions: MapSet.t(String.t()),
          stubs: %{String.t() => pos_integer()}
        }

  @spec analyze([tuple()]) :: analysis()
  def analyze(stmts) do
    acc = %{
      labels: [],
      jump_targets: MapSet.new(),
      callsub_targets: MapSet.new(),
      events: [],
      assigned_names: MapSet.new(),
      local_functions: MapSet.new(),
      stubs: %{}
    }

    acc = Enum.reduce(stmts, acc, &walk_stmt/2)

    %{
      acc
      | labels: Enum.reverse(acc.labels),
        events: acc.labels |> Enum.reverse() |> Enum.filter(&event?/1)
    }
  end

  defp event?("On" <> _), do: true
  defp event?(_), do: false

  # -- statements --------------------------------------------------------------

  defp walk_stmt({:label, name}, acc), do: %{acc | labels: [name | acc.labels]}

  defp walk_stmt({:goto, label}, acc),
    do: %{acc | jump_targets: MapSet.put(acc.jump_targets, String.downcase(label))}

  defp walk_stmt({:menu, pairs}, acc) do
    acc = Enum.reduce(pairs, acc, fn {text, _label}, a -> walk_expr(text, a) end)

    targets =
      Enum.reduce(pairs, acc.jump_targets, fn {_, label}, s ->
        MapSet.put(s, String.downcase(label))
      end)

    %{acc | jump_targets: targets}
  end

  defp walk_stmt({:cmd, "callsub", [{:name, label} | args]}, acc) do
    acc = walk_exprs(args, acc)
    %{acc | callsub_targets: MapSet.put(acc.callsub_targets, String.downcase(label))}
  end

  defp walk_stmt({:cmd, "input", [target | args]}, acc),
    do: walk_exprs(args, assign_target(acc, target))

  defp walk_stmt({:cmd, "setarray", [target | values]}, acc),
    do: walk_exprs(values, assign_target(acc, target))

  defp walk_stmt({:cmd, name, args}, acc), do: walk_exprs(args, count_buildin(acc, name))

  defp walk_stmt({:assign, target, expr}, acc),
    do: walk_expr(expr, assign_target(acc, target))

  defp walk_stmt({:block, stmts}, acc), do: Enum.reduce(stmts, acc, &walk_stmt/2)

  defp walk_stmt({:if, cond_expr, then_stmts, else_stmts}, acc) do
    acc = walk_expr(cond_expr, acc)
    acc = Enum.reduce(then_stmts, acc, &walk_stmt/2)
    Enum.reduce(else_stmts, acc, &walk_stmt/2)
  end

  defp walk_stmt({:switch, expr, clauses}, acc) do
    acc = walk_expr(expr, acc)

    Enum.reduce(clauses, acc, fn {values, stmts}, a ->
      a = values |> Enum.reject(&(&1 == :default)) |> walk_exprs(a)
      Enum.reduce(stmts, a, &walk_stmt/2)
    end)
  end

  defp walk_stmt({:while, cond_expr, body}, acc),
    do: Enum.reduce(body, walk_expr(cond_expr, acc), &walk_stmt/2)

  defp walk_stmt({:do_while, body, cond_expr}, acc),
    do: walk_expr(cond_expr, Enum.reduce(body, acc, &walk_stmt/2))

  defp walk_stmt({:for, init, cond_expr, step, body}, acc) do
    acc = Enum.reduce(init, acc, &walk_stmt/2)
    acc = walk_expr(cond_expr, acc)
    acc = Enum.reduce(step, acc, &walk_stmt/2)
    Enum.reduce(body, acc, &walk_stmt/2)
  end

  defp walk_stmt({:function, name, stmts}, acc) do
    acc = %{acc | local_functions: MapSet.put(acc.local_functions, name)}
    Enum.reduce(stmts, acc, &walk_stmt/2)
  end

  defp walk_stmt({:fn_decl, name}, acc),
    do: %{acc | local_functions: MapSet.put(acc.local_functions, name)}

  defp walk_stmt({:expr, expr}, acc), do: walk_expr(expr, acc)
  defp walk_stmt({:return, nil}, acc), do: acc
  defp walk_stmt({:return, expr}, acc), do: walk_expr(expr, acc)
  defp walk_stmt({:break}, acc), do: acc
  defp walk_stmt({:continue}, acc), do: acc

  defp assign_target(acc, {:name, name}),
    do: %{acc | assigned_names: MapSet.put(acc.assigned_names, name)}

  defp assign_target(acc, {:index, base, index}),
    do: walk_expr(index, assign_target(acc, base))

  defp assign_target(acc, _other), do: acc

  # -- expressions -------------------------------------------------------------

  defp walk_exprs(exprs, acc), do: Enum.reduce(exprs, acc, &walk_expr/2)

  defp walk_expr({:call, "callsub", [{:name, label} | args]}, acc) do
    acc = walk_exprs(args, acc)
    %{acc | callsub_targets: MapSet.put(acc.callsub_targets, String.downcase(label))}
  end

  defp walk_expr({:call, name, args}, acc), do: walk_exprs(args, count_buildin(acc, name))

  defp walk_expr({:bin, _op, l, r}, acc), do: walk_expr(r, walk_expr(l, acc))
  defp walk_expr({:ternary, c, t, f}, acc), do: walk_expr(f, walk_expr(t, walk_expr(c, acc)))
  defp walk_expr({:index, base, index}, acc), do: walk_expr(index, walk_expr(base, acc))
  defp walk_expr({:neg, e}, acc), do: walk_expr(e, acc)
  defp walk_expr({:not, e}, acc), do: walk_expr(e, acc)
  defp walk_expr({:bnot, e}, acc), do: walk_expr(e, acc)
  defp walk_expr({:post_inc, e}, acc), do: assign_target(acc, e)
  defp walk_expr({:post_dec, e}, acc), do: assign_target(acc, e)
  defp walk_expr(_leaf, acc), do: acc

  defp count_buildin(acc, name) do
    if name in @native_cmds or CommandMap.supported?(name) or
         MapSet.member?(acc.local_functions, name) do
      acc
    else
      %{acc | stubs: Map.update(acc.stubs, name, 1, &(&1 + 1))}
    end
  end
end
