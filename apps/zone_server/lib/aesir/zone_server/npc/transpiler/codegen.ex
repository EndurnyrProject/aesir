defmodule Aesir.ZoneServer.Npc.Transpiler.Codegen do
  @moduledoc """
  Emits an Elixir NPC module from a parsed rAthena script body.

  Translation model:

  - Statements thread `ctx` by rebinding (`ctx = mes(ctx, "…")`); runs of
    consecutive `ctx`-threading calls then collapse into pipe chains
    (`ctx |> mes("…") |> close()`), mirroring the hand-written NPC style.
  - `close`/`end` terminate the script by throwing `{:script_end, ctx}`,
    which unwinds the whole call stack (subs, callfunc modules, loop
    helpers) exactly like rAthena stops execution there. The `on_talk` and
    `on_event` entry points catch it and return the ctx, so every entry
    honors its `Ctx.t()` contract; a global function's `call/2` does not
    catch, so its `close`/`end` still ends the calling script. Tail-position
    throws are rewritten back into plain returns. `close2`/`close3` flush
    the CLOSE frame and continue.
  - Top-level labels split the body into segments. `goto`/`menu` targets
    become private functions that end by throwing `{:script_end, ctx}` or
    fall through by tail-calling the next segment, which makes `goto` safe
    from any nesting depth. `callsub` targets become subroutines returning
    `{ctx, value}`.
  - Loops become recursive helper functions; `break`/`continue` compile to
    `throw` only when they occur nested below the loop body's top level.
  - Blocking or effectful calls in expression position (`select`,
    `callfunc`, local functions, `++`) are hoisted into bindings above the
    statement, so expression rendering stays pure.
  - Unsupported buildins emit `todo(ctx, name, args)` (statement) or
    `Todo.call!(name, args)` (expression); unresolved constants emit
    `Todo.const!(name)`. All raise `NotImplementedError` when reached.

  The emitter keeps its per-run state (temp counter, deferred function
  definitions, usage flags) in the process dictionary; `generate/2` resets it,
  and transpilation is a single-process mix task.
  """

  require Logger

  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CatalogNotLoadedError
  alias Aesir.ZoneServer.Npc.Transpiler.Analyzer
  alias Aesir.ZoneServer.Npc.Transpiler.CommandMap
  alias Aesir.ZoneServer.Npc.Transpiler.FunctionIndex
  alias Aesir.ZoneServer.Npc.Transpiler.ModuleName
  alias Aesir.ZoneServer.Npc.Transpiler.Parser
  alias Aesir.ZoneServer.Npc.Transpiler.Resolver

  @comparisons %{==: "==", !=: "!=", <: "<", <=: "<=", >: ">", >=: ">="}
  @arith %{+: "+", -: "-", *: "*"}
  @bitwise %{&: "band", |: "bor", ^: "bxor", shl: "bsl", shr: "bsr"}
  @rathena_calls %{
    "compare" => [2],
    "preg_match" => [2, 3],
    "getstrlen" => [1],
    "pow" => [2],
    "charat" => [2],
    "strtoupper" => [1],
    "substr" => [3],
    "charisalpha" => [2],
    "delchar" => [2],
    "countstr" => [2, 3],
    "insertchar" => [3],
    "replacestr" => [3, 4, 5],
    "strpos" => [2, 3],
    "strtolower" => [1]
  }

  # rAthena `e_questinfo_types` / `e_questinfo_markcolor` (script.hpp) → the
  # client icon/color ints the `questinfo` bubble carries. `QTYPE_NONE` (9999)
  # clears a bubble.
  @quest_icons %{
    "QTYPE_QUEST" => 0,
    "QTYPE_QUEST2" => 1,
    "QTYPE_JOB" => 2,
    "QTYPE_JOB2" => 3,
    "QTYPE_EVENT" => 4,
    "QTYPE_EVENT2" => 5,
    "QTYPE_WARG" => 6,
    "QTYPE_CLICKME" => 6,
    "QTYPE_DAILYQUEST" => 7,
    "QTYPE_WARG2" => 8,
    "QTYPE_EVENT3" => 8,
    "QTYPE_JOBQUEST" => 9,
    "QTYPE_JUMPING_PORING" => 10,
    "QTYPE_NONE" => 9999
  }
  @quest_marks %{
    "QMARK_NONE" => 0,
    "QMARK_YELLOW" => 1,
    "QMARK_GREEN" => 2,
    "QMARK_PURPLE" => 3
  }

  # rAthena `navigateto` service flags (`NAV_*`) → the client int. The
  # default when the flag is omitted is NAV_KAFRA_AND_AIRSHIP (101).
  @nav_flags %{
    "NAV_NONE" => 0,
    "NAV_AIRSHIP_ONLY" => 1,
    "NAV_SCROLL_ONLY" => 10,
    "NAV_AIRSHIP_AND_SCROLL" => 11,
    "NAV_KAFRA_ONLY" => 100,
    "NAV_KAFRA_AND_AIRSHIP" => 101,
    "NAV_KAFRA_AND_SCROLL" => 110,
    "NAV_ALL" => 111
  }

  @script_end "throw({:script_end, ctx})"

  @pipe_rebind ~r/^ctx = ([a-z_][a-zA-Z0-9_]*[!?]?)\(ctx(?:, (.+))?\)$/
  @pipe_call ~r/^([A-Za-z_][A-Za-z0-9_.]*[!?]?)\(ctx(?:, (.+))?\)$/
  @pipe_bind ~r/^(\{ctx, [A-Za-z0-9_]+\}) = ([A-Za-z_][A-Za-z0-9_.]*[!?]?)\(ctx(?:, (.+))?\)$/
  @ctx_word ~r/\bctx\b/

  @typedoc """
  Options: `:module` (full module name string), `:spawns` (resolved placement
  maps for the `use` line; `[]` for floating/functions), `:kind`
  (`:script | :floating | :function`), `:scope` (body content scope, defaults
  to `:shared`), `:functions` (scoped global helper index), `:source`
  (file:line provenance for the moduledoc and helper-link failures).
  """
  @type opts :: map()

  @spec generate(String.t(), opts()) :: {:ok, String.t()} | {:error, term()}
  def generate(body, opts) do
    with {:ok, ast} <- Parser.parse_body(body) do
      analysis = Analyzer.analyze(ast)
      reset_state()
      {ast, unresolvable} = hoist_nested_labels(ast, analysis)

      env = %{
        a: analysis,
        fns: Map.get(opts, :functions, %{}),
        labels: label_fns(analysis, unresolvable),
        scope: Map.get(opts, :scope, :shared),
        source: opts.source,
        sub: opts.kind == :function,
        break: nil,
        loop: nil,
        catch_return: false,
        sprites: Map.get(opts, :sprites, %{})
      }

      source = build_module(ast, env, opts)
      {:ok, IO.iodata_to_binary(Code.format_string!(source)) <> "\n"}
    end
  rescue
    error in CatalogNotLoadedError -> reraise error, __STACKTRACE__
    error -> {:error, {:codegen, Exception.message(error)}}
  end

  # -- module assembly ---------------------------------------------------------

  defp build_module(ast, env, opts) do
    {main, segments} = segment(ast, env)
    catch_return? = env.sub and needs_return_catch?(main)
    main_env = %{env | catch_return: catch_return?}
    {main_lines, main_terminal} = emit_block(main, main_env)

    main_body =
      case opts.kind do
        :function ->
          main_lines ++ main_fall_through(:function, main_terminal, segments, env)

        _ ->
          tail_return(main_lines ++ main_fall_through(opts.kind, main_terminal, segments, env))
      end

    segment_defs = emit_segments(segments, env)
    deferred = get_defs()
    catch_end? = catches_script_end?(main_body, segment_defs ++ deferred)

    entry =
      case opts.kind do
        :function -> function_entry(main_body, catch_return?)
        _ -> on_talk_entry(main_body, catch_end?)
      end

    """
    defmodule #{opts.module} do
      @moduledoc \"\"\"
      Transpiled from rAthena #{opts.source}.

      Regenerated by `mix aesir.import.npcs`; hand edits are detected through
      the transpile manifest and future imports land in `_conflicts/` instead
      of overwriting them.
      \"\"\"

      #{header(opts)}
      #{aliases()}
      #{event_clauses(env, catch_end?)}
      #{entry}
      #{Enum.join(segment_defs, "\n\n")}
      #{Enum.join(deferred, "\n\n")}
    end
    """
  end

  # `warn: false`: a transpiled function whose body happens to touch no DSL
  # primitive (a pure string helper) must not fail warnings-as-errors builds.
  defp header(%{kind: :function}), do: "import Aesir.ZoneServer.Script.Dsl, warn: false"

  defp header(opts) do
    scope = Map.get(opts, :scope, :shared)
    spawns = Enum.map_join(opts.spawns, ",\n", &render_spawn(&1, scope))
    "use Aesir.ZoneServer.Npc, scope: #{inspect(scope)}, spawn: [#{spawns}]"
  end

  defp render_spawn(s, body_scope) do
    fields =
      [
        "map: #{inspect(s.map)}",
        "x: #{s.x}",
        "y: #{s.y}",
        "dir: #{s.dir}",
        "sprite: #{s.sprite}",
        "name: #{inspect(s.name)}",
        "scope: #{inspect(Map.get(s, :scope, body_scope))}"
      ] ++ optional_spawn_fields(s)

    "%{" <> Enum.join(fields, ", ") <> "}"
  end

  defp optional_spawn_fields(s) do
    [
      Map.has_key?(s, :unique_name) && "unique_name: #{inspect(s.unique_name)}",
      Map.has_key?(s, :trigger) && "trigger: {#{elem(s.trigger, 0)}, #{elem(s.trigger, 1)}}"
    ]
    |> Enum.filter(& &1)
  end

  defp aliases do
    [
      flag?(:game_mode) && "alias Aesir.Commons.GameMode",
      flag?(:rathena) && "alias Aesir.ZoneServer.Script.Rathena",
      flag?(:todo_mod) && "alias Aesir.ZoneServer.Script.Todo"
    ]
    |> Enum.filter(& &1)
    |> Enum.join("\n")
  end

  # `On*` labels wire straight to `on_event/2`; the macro derives `events/0`
  # from the clause heads, so no explicit list is emitted. `OnTouch_` (the
  # area-trigger variant) normalizes to the plain `"OnTouch"` head the engine
  # actually dispatches — a script defining both collapses to one clause,
  # keeping the first and warning.
  defp event_clauses(env, catch_end?) do
    case env.a.events |> Enum.map(&{normalized_event_head(&1), &1}) |> dedupe_event_heads() do
      [] ->
        ""

      pairs ->
        clauses =
          Enum.map_join(pairs, "\n", fn {head, label} ->
            event_clause(head, event_call(env, label), catch_end?)
          end)

        "@impl true\n" <> clauses
    end
  end

  defp event_clause(head, call, false), do: "def on_event(#{inspect(head)}, ctx), do: #{call}"

  defp event_clause(head, call, true) do
    """
    def on_event(#{inspect(head)}, ctx) do
      #{call}
    #{script_end_catch()}
    end
    """
  end

  defp normalized_event_head(label) do
    if String.downcase(label) == "ontouch_", do: "OnTouch", else: label
  end

  defp dedupe_event_heads(pairs) do
    {kept, _seen} =
      Enum.reduce(pairs, {[], MapSet.new()}, fn {head, label}, {acc, seen} ->
        if MapSet.member?(seen, head) do
          Logger.warning(
            "npc transpiler: duplicate on_event clause head #{inspect(head)} " <>
              "(label #{inspect(label)}), keeping the first"
          )

          {acc, seen}
        else
          {[{head, label} | acc], MapSet.put(seen, head)}
        end
      end)

    Enum.reverse(kept)
  end

  # A label that is also a `callsub` target compiles to a `(ctx, args)`
  # subroutine returning `{ctx, value}`; unwrap it so the clause still
  # returns ctx like every other on_event/on_talk entry point.
  defp event_call(env, label) do
    if MapSet.member?(env.a.callsub_targets, String.downcase(label)) do
      "elem(#{fn_name(env, label)}(ctx, []), 0)"
    else
      "#{fn_name(env, label)}(ctx)"
    end
  end

  defp on_talk_entry(body_lines, catch_end?) do
    """
    @impl true
    def on_talk(#{param(body_lines)}) do
      #{join_body(body_lines)}
    #{if catch_end?, do: script_end_catch(), else: ""}
    end
    """
  end

  # The entry-point half of the `{:script_end, ctx}` protocol: a `close`/`end`
  # anywhere below (branches, subs, callfunc modules) unwinds here and the
  # entry returns the ctx it carried. Emitted only when this module can throw —
  # a remaining non-tail script-end throw, or a `callfunc` into another
  # transpiled module whose `close`/`end` propagates through `call/2`.
  defp script_end_catch do
    """
    catch
    :throw, {:script_end, ctx} -> ctx
    """
  end

  defp catches_script_end?(main_body, defs) do
    Enum.any?(main_body ++ defs, fn code ->
      String.contains?(code, @script_end) or String.contains?(code, ".call(ctx")
    end)
  end

  defp function_entry(body_lines, catch_return?) do
    body = join_body(body_lines)
    args = if String.contains?(body, "args"), do: "args", else: "_args"

    """
    @doc "Callable rAthena global function; returns `{ctx, return_value}`."
    def call(#{param(body_lines)}, #{args}) do
      #{wrap_return_catch(body, catch_return?)}
    end
    """
  end

  defp join_body(lines), do: lines |> pipe_chains() |> Enum.join("\n")

  # -- pipe chains ---------------------------------------------------------

  # Folds runs of consecutive `ctx = f(ctx, …)` rebinds — plus an optional
  # capping `g(ctx, …)` tail call, `{ctx, v} = g(ctx, …)` binding, or a
  # block-final bare `ctx` — into a single `|>` chain, mirroring the
  # hand-written NPC style. A call whose other arguments mention `ctx` may
  # only open a chain: mid-chain it would read the pre-pipe binding.
  defp pipe_chains(lines), do: pipe_chains(lines, [])

  defp pipe_chains([], out), do: Enum.reverse(out)

  defp pipe_chains([line | rest], out) do
    case pipe_step(@pipe_rebind, line) do
      nil -> pipe_chains(rest, [line | out])
      step -> pipe_run(rest, [line], [step], out)
    end
  end

  # pipe_run(remaining, run lines (reversed), run steps (reversed), out)
  defp pipe_run([], run_lines, steps, out),
    do: pipe_chains([], flush_run(run_lines, steps) ++ out)

  defp pipe_run([line | rest] = remaining, run_lines, steps, out) do
    rebind = pipe_step(@pipe_rebind, line)
    bind = bind_step(line)
    call = pipe_step(@pipe_call, line)

    cond do
      safe_step?(rebind) ->
        pipe_run(rest, [line | run_lines], [rebind | steps], out)

      bind != nil and safe_step?(elem(bind, 1)) ->
        {target, step} = bind
        pipe_chains(rest, [chain(target <> " = ", [step | steps]) | out])

      safe_step?(call) ->
        pipe_chains(rest, [chain("", [call | steps]) | out])

      line == "ctx" and block_final?(rest) ->
        pipe_chains(rest, [value_run(run_lines, steps) | out])

      true ->
        pipe_chains(remaining, flush_run(run_lines, steps) ++ out)
    end
  end

  defp flush_run(run_lines, steps) do
    if length(steps) >= 2, do: [chain("ctx = ", steps)], else: run_lines
  end

  # A run whose value falls off the block end: a real run pipes; a single
  # rebind just loses the dead `ctx =` binding.
  defp value_run([line], [_step]), do: String.replace_prefix(line, "ctx = ", "")
  defp value_run(_run_lines, steps), do: chain("", steps)

  defp chain(prefix, reversed_steps) do
    calls = reversed_steps |> Enum.reverse() |> Enum.map(&step_call/1)
    prefix <> Enum.join(["ctx" | calls], " |> ")
  end

  defp step_call({fun, nil}), do: "#{fun}()"
  defp step_call({fun, args}), do: "#{fun}(#{args})"

  defp pipe_step(regex, line) do
    case not String.contains?(line, "\n") && Regex.run(regex, line) do
      [_, fun] -> {fun, nil}
      [_, fun, args] -> {fun, args}
      _ -> nil
    end
  end

  defp bind_step(line) do
    case not String.contains?(line, "\n") && Regex.run(@pipe_bind, line) do
      [_, target, fun] -> {target, {fun, nil}}
      [_, target, fun, args] -> {target, {fun, args}}
      _ -> nil
    end
  end

  defp safe_step?(nil), do: false
  defp safe_step?({_fun, nil}), do: true
  defp safe_step?({_fun, args}), do: not Regex.match?(@ctx_word, args)

  # Emitted bare `ctx` lines only ever close a block; merging one away is
  # only allowed where the next line proves that (or the body ends).
  defp block_final?([]), do: true

  defp block_final?([next | _]),
    do: next in ["else", "end", "catch"] or String.ends_with?(next, "->")

  defp param(body_lines) do
    if Enum.any?(body_lines, &String.contains?(&1, "ctx")), do: "ctx", else: "_ctx"
  end

  # Inside a subroutine/function body, helper functions (loops, label
  # segments) thread the enclosing `args` through so `getarg` keeps working.
  defp helper_call(%{sub: true}), do: ", args"
  defp helper_call(_env), do: ""

  defp helper_params(lines, %{sub: true}) do
    args = if Enum.any?(lines, &String.contains?(&1, "args")), do: "args", else: "_args"
    "#{param(lines)}, #{args}"
  end

  defp helper_params(lines, _env), do: param(lines)

  # -- segmentation ------------------------------------------------------------

  # Splits top-level statements at labels that need their own function:
  # jump targets, callsub targets and event labels. Other labels are inert.
  # A label closes the segment being accumulated and opens its own.
  defp segment(stmts, env) do
    {segs, {kind, name, acc}} =
      Enum.reduce(stmts, {[], {:main, nil, []}}, fn
        {:label, label} = stmt, {segs, {kind, name, acc}} ->
          case segment_kind(label, env.a) do
            nil -> {segs, {kind, name, [stmt | acc]}}
            new_kind -> {[{kind, name, Enum.reverse(acc)} | segs], {new_kind, label, []}}
          end

        stmt, {segs, {kind, name, acc}} ->
          {segs, {kind, name, [stmt | acc]}}
      end)

    [{:main, nil, main} | rest] = Enum.reverse([{kind, name, Enum.reverse(acc)} | segs])
    {main, rest}
  end

  defp segment_kind(name, analysis) do
    key = String.downcase(name)

    cond do
      MapSet.member?(analysis.callsub_targets, key) -> :sub
      MapSet.member?(analysis.jump_targets, key) -> :jump
      String.starts_with?(name, "On") -> :event
      true -> nil
    end
  end

  # -- nested-label hoisting ----------------------------------------------------

  defp hoist_nested_labels(ast, analysis) do
    {body, hoisted, unresolvable} = hoist_list(ast, analysis, true, [], [], MapSet.new())

    appended =
      hoisted
      |> Enum.reverse()
      |> Enum.flat_map(fn {label, stmts} -> [{:label, label} | stmts] end)

    {body ++ appended, unresolvable}
  end

  defp hoist_list([], _analysis, _is_top, acc, hoisted, unresolvable),
    do: {Enum.reverse(acc), hoisted, unresolvable}

  defp hoist_list([{:label, label} | rest], analysis, is_top, acc, hoisted, unresolvable) do
    if is_top or not hoistable?(label, analysis) do
      hoist_list(rest, analysis, is_top, [{:label, label} | acc], hoisted, unresolvable)
    else
      if terminates?(rest) do
        {rest, hoisted, unresolvable} =
          hoist_list(rest, analysis, false, [], hoisted, unresolvable)

        hoist_list(
          [],
          analysis,
          is_top,
          [{:goto, label} | acc],
          [{label, rest} | hoisted],
          unresolvable
        )
      else
        hoist_list(
          rest,
          analysis,
          is_top,
          [{:label, label} | acc],
          hoisted,
          MapSet.put(unresolvable, String.downcase(label))
        )
      end
    end
  end

  defp hoist_list([stmt | rest], analysis, is_top, acc, hoisted, unresolvable) do
    {stmt, hoisted, unresolvable} = hoist_stmt(stmt, analysis, hoisted, unresolvable)
    hoist_list(rest, analysis, is_top, [stmt | acc], hoisted, unresolvable)
  end

  defp hoist_stmt({:if, cond_expr, then_stmts, else_stmts}, analysis, hoisted, unresolvable) do
    {then_stmts, hoisted, unresolvable} =
      hoist_list(then_stmts, analysis, false, [], hoisted, unresolvable)

    {else_stmts, hoisted, unresolvable} =
      hoist_list(else_stmts, analysis, false, [], hoisted, unresolvable)

    {{:if, cond_expr, then_stmts, else_stmts}, hoisted, unresolvable}
  end

  defp hoist_stmt({:switch, expr, clauses}, analysis, hoisted, unresolvable) do
    {clauses, {hoisted, unresolvable}} =
      Enum.map_reduce(clauses, {hoisted, unresolvable}, fn {values, stmts},
                                                           {hoisted, unresolvable} ->
        {stmts, hoisted, unresolvable} =
          hoist_list(stmts, analysis, false, [], hoisted, unresolvable)

        {{values, stmts}, {hoisted, unresolvable}}
      end)

    {{:switch, expr, clauses}, hoisted, unresolvable}
  end

  defp hoist_stmt({:while, cond_expr, body}, analysis, hoisted, unresolvable) do
    {body, hoisted, unresolvable} = hoist_list(body, analysis, false, [], hoisted, unresolvable)
    {{:while, cond_expr, body}, hoisted, unresolvable}
  end

  defp hoist_stmt({:do_while, body, cond_expr}, analysis, hoisted, unresolvable) do
    {body, hoisted, unresolvable} = hoist_list(body, analysis, false, [], hoisted, unresolvable)
    {{:do_while, body, cond_expr}, hoisted, unresolvable}
  end

  defp hoist_stmt({:for, init, cond_expr, step, body}, analysis, hoisted, unresolvable) do
    {init, hoisted, unresolvable} = hoist_list(init, analysis, false, [], hoisted, unresolvable)
    {step, hoisted, unresolvable} = hoist_list(step, analysis, false, [], hoisted, unresolvable)
    {body, hoisted, unresolvable} = hoist_list(body, analysis, false, [], hoisted, unresolvable)
    {{:for, init, cond_expr, step, body}, hoisted, unresolvable}
  end

  defp hoist_stmt({:function, name, stmts}, analysis, hoisted, unresolvable) do
    {stmts, hoisted, unresolvable} = hoist_list(stmts, analysis, false, [], hoisted, unresolvable)
    {{:function, name, stmts}, hoisted, unresolvable}
  end

  defp hoist_stmt({:block, stmts}, analysis, hoisted, unresolvable) do
    {stmts, hoisted, unresolvable} = hoist_list(stmts, analysis, false, [], hoisted, unresolvable)
    {{:block, stmts}, hoisted, unresolvable}
  end

  defp hoist_stmt(other, _analysis, hoisted, unresolvable), do: {other, hoisted, unresolvable}

  defp hoistable?(label, analysis) do
    key = String.downcase(label)
    MapSet.member?(analysis.jump_targets, key) or MapSet.member?(analysis.callsub_targets, key)
  end

  defp terminates?(stmts) do
    case List.last(stmts) do
      {:cmd, name, _} when name in ["close", "end", "close2", "close3"] -> true
      {:goto, _} -> true
      {:menu, _} -> true
      {:return, _} -> true
      {:break} -> true
      {:continue} -> true
      _ -> false
    end
  end

  defp emit_segments(segments, env) do
    segments
    |> Enum.with_index()
    |> Enum.map(fn {{kind, name, stmts}, idx} ->
      next = Enum.at(segments, idx + 1)
      emit_segment(kind, name, stmts, next, env)
    end)
  end

  defp emit_segment(:sub, name, stmts, _next, env) do
    catch_return? = needs_return_catch?(stmts)
    {lines, terminal} = emit_block(stmts, %{env | sub: true, catch_return: catch_return?})
    lines = lines ++ if terminal == :cont, do: ["{ctx, nil}"], else: []
    args = if Enum.any?(lines, &String.contains?(&1, "args")), do: "args", else: "_args"

    """
    defp #{fn_name(env, name)}(#{param(lines)}, #{args}) do
      #{wrap_return_catch(join_body(lines), catch_return?)}
    end
    """
  end

  defp emit_segment(kind, name, stmts, next, env) do
    {lines, terminal} = emit_block(stmts, env)
    lines = lines ++ fall_through(terminal, List.wrap(next), env)
    lines = if kind == :event, do: tail_return(lines), else: lines
    visibility = if kind == :event, do: "def", else: "defp"

    """
    #{visibility} #{fn_name(env, name)}(#{helper_params(lines, env)}) do
      #{join_body(lines)}
    end
    """
  end

  # A script whose body ends in `close`/`end` throws in tail position, where
  # unwinding to the entry catch is pure ceremony: the tail rewrite turns the
  # throw back into a plain ctx return (the wrapper terminates the task the
  # same way). A preceding `ctx = …` rebind becomes the tail expression itself
  # — every rebind evaluates to ctx, so unbinding keeps the value and drops
  # the dead binding. Non-tail throws (in branches, or anywhere in a global
  # function's `call/2`) stay: those must unwind for real.
  defp tail_return(lines) do
    case List.last(lines) do
      @script_end ->
        case Enum.drop(lines, -1) do
          [] -> ["ctx"]
          head -> unbind_tail(head)
        end

      _ ->
        lines
    end
  end

  defp unbind_tail(head) do
    case List.last(head) do
      <<"ctx = ", expr::binary>> -> List.replace_at(head, -1, expr)
      _ -> head ++ ["ctx"]
    end
  end

  # A `callfunc` target's `call/2` must always return `{ctx, value}` (callers
  # bind `{ctx, _} = ...`). The shared `fall_through` ends a runs-off-the-end
  # path with a bare `ctx` (correct for a dialog entry point, which returns
  # ctx) — for a function that trailing `ctx` is the return value and must be a
  # tuple instead. Rewrite it to `{ctx, nil}` wherever it lands (no segment, or
  # a fall into a subroutine/event segment).
  defp main_fall_through(:function, terminal, segments, env) do
    case fall_through(terminal, segments, env) do
      [] ->
        []

      lines ->
        if List.last(lines) == "ctx",
          do: List.replace_at(lines, -1, "{ctx, nil}"),
          else: lines
    end
  end

  defp main_fall_through(_kind, terminal, segments, env),
    do: fall_through(terminal, segments, env)

  # A label function that runs off its end falls through into the next
  # segment; the last one (or a fall into a subroutine) ends the script.
  defp fall_through(terminal, _next, _env) when terminal != :cont, do: []
  defp fall_through(:cont, [], _env), do: ["ctx"]

  defp fall_through(:cont, [{:jump, name, _} | _], env),
    do: ["#{fn_name(env, name)}(ctx#{helper_call(env)})"]

  # Falling into an event label ends normal flow (events run on their own
  # engine triggers, not as dialog continuation).
  defp fall_through(:cont, [{:event, _, _} | _], _env), do: ["ctx"]

  defp fall_through(:cont, [{:sub, name, _} | _], env),
    do: ["{ctx, _} = #{fn_name(env, name)}(ctx, [])", "ctx"]

  # Label → emitted function name. Keyed by downcased label, so references
  # resolve case-insensitively like rAthena's own label lookup.
  defp label_fns(analysis, unresolvable) do
    analysis.labels
    |> Enum.reject(&MapSet.member?(unresolvable, String.downcase(&1)))
    |> Enum.reduce({%{}, MapSet.new()}, fn label, {map, taken} ->
      prefix =
        cond do
          MapSet.member?(analysis.callsub_targets, String.downcase(label)) -> "s_"
          String.starts_with?(label, "On") -> "ev_"
          true -> "l_"
        end

      base = prefix <> ModuleName.slug(label)
      name = if MapSet.member?(taken, base), do: base <> "_#{map_size(map)}", else: base
      {Map.put(map, String.downcase(label), name), MapSet.put(taken, name)}
    end)
    |> elem(0)
  end

  defp fn_name(env, label), do: Map.fetch!(env.labels, String.downcase(label))

  defp label?(env, label), do: Map.has_key?(env.labels, String.downcase(label))

  # -- statement emission ------------------------------------------------------

  # Emits a statement list; returns `{lines, terminal}` where terminal is
  # `:cont` (flow continues), `:stop` (close/end/goto/return — nothing runs
  # after), `:break` or `:continue` (loop control reached top level).
  # Statements after a terminal are dead code and dropped.
  defp emit_block(stmts, env) do
    Enum.reduce_while(stmts, {[], :cont}, fn stmt, {lines, :cont} ->
      {new_lines, terminal} = emit_stmt(stmt, env)

      case terminal do
        :cont -> {:cont, {lines ++ new_lines, :cont}}
        other -> {:halt, {lines ++ new_lines, other}}
      end
    end)
  end

  defp emit_stmt({:block, stmts}, env), do: emit_block(stmts, env)
  defp emit_stmt({:label, _}, _env), do: {[], :cont}
  defp emit_stmt({:fn_decl, _}, _env), do: {[], :cont}

  # Expression statement: evaluate for effects (hoisting) and discard.
  defp emit_stmt({:expr, expr}, env) do
    {pre, _expr} = hoist(expr, env)
    {pre, :cont}
  end

  defp emit_stmt({:function, name, stmts}, env) do
    catch_return? = needs_return_catch?(stmts)

    {lines, terminal} =
      emit_block(stmts, %{env | sub: true, break: nil, loop: nil, catch_return: catch_return?})

    lines = lines ++ if terminal == :cont, do: ["{ctx, nil}"], else: []
    args = if Enum.any?(lines, &String.contains?(&1, "args")), do: "args", else: "_args"

    defer("""
    defp #{local_fn_name(name)}(#{param(lines)}, #{args}) do
      #{wrap_return_catch(join_body(lines), catch_return?)}
    end
    """)

    {[], :cont}
  end

  defp emit_stmt({:goto, label}, env) do
    if label?(env, label) do
      {["#{fn_name(env, label)}(ctx#{helper_call(env)})"], :stop}
    else
      flag(:todo_fun)
      {["ctx = todo(ctx, :goto, [#{inspect(label)}])"], :cont}
    end
  end

  defp emit_stmt({:menu, pairs}, env) do
    {pre, texts} = hoist_all(Enum.map(pairs, &elem(&1, 0)), env)
    options = "[" <> Enum.map_join(texts, ", ", &render_str(&1, env)) <> "]"

    clauses =
      pairs
      |> Enum.with_index(1)
      |> Enum.map(fn {{_, label}, idx} ->
        if label?(env, label) do
          "#{idx} -> #{fn_name(env, label)}(ctx#{helper_call(env)})"
        else
          flag(:todo_fun)
          "#{idx} -> todo(ctx, :goto, [#{inspect(label)}])"
        end
      end)

    lines =
      pre ++
        ["{ctx, choice} = select(ctx, #{options})", ""] ++
        ["case choice do"] ++ clauses ++ ["_ -> ctx", "end"]

    {lines, :stop}
  end

  # A `return` nested below the function's top level (inside an if/switch/loop
  # that also has a continuing path) can't compile to a plain `{ctx, value}`
  # tail expression — that would bind the tuple back into `ctx`. It throws to
  # the try/catch the enclosing function body is wrapped in (see
  # `wrap_return_catch`/`needs_return_catch?`), short-circuiting like rAthena's
  # `return` regardless of nesting or loop-helper boundaries.
  defp emit_stmt({:return, expr}, %{sub: true, catch_return: true} = env) do
    {pre, expr} = hoist(expr, env)
    value = if expr, do: render(expr, env), else: "nil"
    {pre ++ ["throw({:script_return, {ctx, #{value}}})"], :stop}
  end

  defp emit_stmt({:return, expr}, %{sub: true} = env) do
    {pre, expr} = hoist(expr, env)
    {pre ++ ["{ctx, #{if expr, do: render(expr, env), else: "nil"}}"], :stop}
  end

  defp emit_stmt({:return, _}, _env), do: {[@script_end], :stop}

  defp emit_stmt({:break}, %{break: nil}), do: {[], :cont}
  defp emit_stmt({:break}, %{break: {:throw, tag}}), do: {["throw({:#{tag}, ctx})"], :stop}
  defp emit_stmt({:break}, %{break: :plain}), do: {[], :break}

  defp emit_stmt({:continue}, %{loop: nil}), do: {[], :cont}
  defp emit_stmt({:continue}, %{loop: {:throw, tag}}), do: {["throw({:#{tag}, ctx})"], :stop}
  defp emit_stmt({:continue}, %{loop: :plain}), do: {[], :continue}

  defp emit_stmt({:if, cond_expr, then_stmts, else_stmts}, env) do
    {pre, cond_expr} = hoist(cond_expr, env)
    {then_lines, then_t} = emit_block(then_stmts, env)
    {else_lines, else_t} = emit_block(else_stmts, env)

    then_body = branch_body(then_lines, then_t)
    else_body = branch_body(else_lines, else_t)

    terminal = merge_terminal(then_t, else_t)
    bind = if terminal == :cont, do: "ctx =", else: ""

    lines =
      pre ++
        ["#{bind} if #{cond_str(cond_expr, env)} do"] ++
        then_body ++ ["else"] ++ else_body ++ ["end"]

    {lines, terminal}
  end

  defp emit_stmt({:switch, expr, clauses}, env), do: emit_switch(expr, clauses, env)
  defp emit_stmt({:while, cond_expr, body}, env), do: emit_loop(:while, cond_expr, [], body, env)

  defp emit_stmt({:do_while, body, cond_expr}, env),
    do: emit_loop(:do_while, cond_expr, [], body, env)

  defp emit_stmt({:for, init, cond_expr, step, body}, env) do
    {init_lines, :cont} = emit_block(init, env)
    {loop_lines, terminal} = emit_loop(:while, cond_expr, step, body, env)
    {init_lines ++ loop_lines, terminal}
  end

  defp emit_stmt({:assign, target, expr}, env), do: emit_assign(target, expr, env)

  # -- command statements --

  defp emit_stmt({:cmd, "mes", args}, env) do
    {pre, args} = hoist_all(args, env)
    text = args |> Enum.map(&render_str(&1, env)) |> concat_all()
    {pre ++ ["ctx = mes(ctx, #{text})"], :cont}
  end

  defp emit_stmt({:cmd, "next", _}, _env), do: {["ctx = next(ctx)"], :cont}
  defp emit_stmt({:cmd, "close", _}, _env), do: {["ctx = close(ctx)", @script_end], :stop}
  defp emit_stmt({:cmd, "end", _}, _env), do: {[@script_end], :stop}

  defp emit_stmt({:cmd, "close2", _}, _env), do: {["ctx = close(ctx)"], :cont}

  # `close3` also clears any displayed cutin alongside the dialog window.
  defp emit_stmt({:cmd, "close3", _}, _env),
    do: {["ctx = close(ctx)", ~s[ctx = cutin(ctx, "", 255)]], :cont}

  defp emit_stmt({:cmd, select, args}, env) when select in ["select", "prompt"] do
    {pre, args} = hoist_all(args, env)
    {pre ++ ["{ctx, _} = select(ctx, #{options(args, env)})"], :cont}
  end

  defp emit_stmt({:cmd, "input", [target]}, env) do
    kind = if str_target?(target), do: ":string", else: ":int"
    tmp = tmp_var()
    {assign_lines, :cont} = emit_assign(target, {:temp, tmp}, env)
    {["{ctx, #{tmp}} = input(ctx, #{kind})" | assign_lines], :cont}
  end

  # `input <var>,<min>{,<max>}`: clamp the entry into range before writing it
  # back; the discarded status is only meaningful in expression position.
  defp emit_stmt({:cmd, "input", [target | bounds]}, env) do
    # Statement position discards the range status, so bind it to `_` rather
    # than a fresh temp — the value would otherwise be an unused variable.
    {_status, lines} = input_lines(target, bounds, env, "_")
    {lines, :cont}
  end

  defp emit_stmt({:cmd, "setarray", [target | values]}, env) do
    {pre, values} = hoist_all(values, env)
    rendered = "[" <> Enum.map_join(values, ", ", &render(&1, env)) <> "]"

    case target do
      # `setarray getd("$arr[0]"), …`: the name keeps its `[start]`; the DSL
      # writes the list of values as consecutive elements from that index.
      {:call, "getd", [name]} ->
        {pre_dyn, name} = hoist(name, env)
        {pre_dyn ++ pre ++ ["ctx = setd(ctx, #{render(name, env)}, #{rendered})"], :cont}

      {:index, base, {:int, 0}} ->
        {pre ++ [set_var(base, rendered, env)], :cont}

      {:index, base, start} ->
        start = render(start, env)
        flag(:rathena)

        lines =
          values
          |> Enum.with_index()
          |> Enum.map(fn {v, i} ->
            set_var(
              base,
              "Rathena.put_at(#{read_var(base, "[]", env)}, #{start} + #{i}, #{render(v, env)}, 0)",
              env
            )
          end)

        {pre ++ lines, :cont}

      _ ->
        {pre ++ [set_var(target, rendered, env)], :cont}
    end
  end

  # `deletearray <array>[<start>]{,<count>}`: removes `count` elements at
  # `start`, shifting later values down; without a count it truncates from
  # `start` to the end, so `[0]` with no count (or a bare name) wipes the array.
  defp emit_stmt({:cmd, "deletearray", [target | count]}, env) do
    {pre, count} = hoist_all(count, env)

    case {target, count} do
      {{:index, base, {:int, 0}}, []} ->
        {pre ++ [set_var(base, "[]", env)], :cont}

      {{:index, base, start}, count} ->
        flag(:rathena)
        count_arg = if count == [], do: ":rest", else: render(hd(count), env)

        value =
          "Rathena.delete_at(#{read_var(base, "[]", env)}, #{render(start, env)}, #{count_arg})"

        {pre ++ [set_var(base, value, env)], :cont}

      {base, _count} ->
        {pre ++ [set_var(base, "[]", env)], :cont}
    end
  end

  # `explode <string_array>,<string>,<delimiter>` writes consecutive split
  # values into the destination array from its optional starting index.
  defp emit_stmt({:cmd, "explode", [target, string, delimiter]}, env) do
    {pre, [string, delimiter]} = hoist_all([string, delimiter], env)
    {base, start} = explode_target(target)
    flag(:rathena)

    values = "Rathena.explode(#{render(string, env)}, #{render(delimiter, env)})"

    updated =
      "Rathena.put_many(#{read_var(base, "[]", env)}, #{render(start, env)}, #{values}, \"\")"

    {pre ++ [set_var(base, updated, env)], :cont}
  end

  # `setd "<name>",<value>{,"<char_id>"}`: write a variable whose full name
  # (scope sigil + optional `[N]`) is built at runtime. The rare rAthena
  # `char_id` tail is dropped; a malformed arity stays a stub.
  defp emit_stmt({:cmd, "setd", [name, value | _rest]}, env) do
    {pre, [name, value]} = hoist_all([name, value], env)
    {pre ++ ["ctx = setd(ctx, #{render(name, env)}, #{render(value, env)})"], :cont}
  end

  defp emit_stmt({:cmd, "setd", args}, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, :setd, [#{rendered}])"], :cont}
  end

  defp emit_stmt({:cmd, "callsub", [{:name, label} | args]}, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["{ctx, _} = #{fn_name(env, label)}(ctx, [#{rendered}])"], :cont}
  end

  # `attachrid <account_id>{,<force>}` re-attaches the script to another player.
  # The DSL returns `{ctx, success}`; statement position discards the flag.
  defp emit_stmt({:cmd, "attachrid", args}, env) do
    {pre, args} = hoist_all(args, env)

    call =
      case args do
        [account_id] ->
          "{ctx, _} = attachrid(ctx, #{render(account_id, env)})"

        [account_id, force] ->
          "{ctx, _} = attachrid(ctx, #{render(account_id, env)}, #{render(force, env)})"

        _other ->
          flag(:todo_fun)
          "ctx = todo(ctx, :attachrid, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
      end

    {pre ++ [call], :cont}
  end

  # A CommandMap-mapped function (hand-curated DSL primitive) wins over a
  # generated helper. Static helper targets stay direct; only a shared caller
  # targeting overlays emits a runtime mode branch.
  defp emit_stmt({:cmd, "callfunc", [{:str, fname} | args]}, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))

    case CommandMap.function(fname) do
      {:ok, %{kind: :command, dsl: dsl}} ->
        {pre ++ ["ctx = #{dsl}(ctx, #{rendered})"], :cont}

      _command_map ->
        case helper_target(env, fname, rendered) do
          {:ok, call} ->
            {pre ++ ["{ctx, _} = #{call}"], :cont}

          :missing ->
            flag(:todo_fun)
            {pre ++ ["ctx = todo(ctx, :callfunc, [#{inspect(fname)}, #{rendered}])"], :cont}
        end
    end
  end

  defp emit_stmt({:cmd, name, args}, env) do
    cond do
      MapSet.member?(env.a.local_functions, name) ->
        {pre, args} = hoist_all(args, env)
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["{ctx, _} = #{local_fn_name(name)}(ctx, [#{rendered}])"], :cont}

      match?({:ok, _}, CommandMap.command(name)) ->
        {:ok, rule} = CommandMap.command(name)
        emit_mapped(name, rule, args, env)

      match?({:ok, %{kind: :command}}, CommandMap.function(name)) ->
        {:ok, %{dsl: dsl}} = CommandMap.function(name)
        {pre, args} = hoist_all(args, env)
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["ctx = #{dsl}(ctx, #{rendered})"], :cont}

      true ->
        {pre, args} = hoist_all(args, env)
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
    end
  end

  defp helper_target(env, fname, rendered) do
    case FunctionIndex.resolve(env.fns, fname, env.scope) do
      {:static, module} ->
        {:ok, "#{module}.call(ctx, [#{rendered}])"}

      {:runtime, targets} ->
        flag(:game_mode)
        {:ok, runtime_helper_target(fname, rendered, targets, env.source)}

      :missing ->
        case Map.fetch(env.fns, fname) do
          :error ->
            :missing

          {:ok, targets} ->
            scopes = targets |> Map.keys() |> Enum.sort()

            raise ArgumentError,
                  "NPC helper #{fname} called from #{env.source} in #{env.scope} scope is incompatible; " <>
                    "available scopes: #{inspect(scopes)}"
        end
    end
  end

  defp runtime_helper_target(fname, rendered, targets, source) do
    branches =
      Enum.map_join([:renewal, :pre_renewal], "\n", fn mode ->
        case Map.fetch(targets, mode) do
          {:ok, module} ->
            "#{inspect(mode)} -> #{module}.call(ctx, [#{rendered}])"

          :error ->
            message = "NPC helper #{fname} called from #{source} has no #{mode} target"
            "#{inspect(mode)} -> raise #{inspect(message)}"
        end
      end)

    "case GameMode.mode() do\n#{branches}\nend"
  end

  defp atom_lit(name), do: inspect(String.to_atom(name))

  defp explode_target({:index, base, start}), do: {base, start}
  defp explode_target(base), do: {base, {:int, 0}}

  # -- mapped commands ---------------------------------------------------------

  defp emit_mapped(_name, %{shape: :heal, dsl: dsl}, args, env) do
    {pre, args} = hoist_all(args, env)
    [hp, sp] = (args ++ [{:int, 0}, {:int, 0}]) |> Enum.take(2)
    {pre ++ ["ctx = #{dsl}(ctx, hp: #{render(hp, env)}, sp: #{render(sp, env)})"], :cont}
  end

  # `warp "<map>",<x>,<y>` — a literal "Random"/"SavePoint" target resolves to
  # the one-argument DSL form at transpile time. Every other map expression,
  # literal or dynamic (`.@map$`, `strnpcinfo(4)`, a concat), is passed through
  # to `warp/4`, which resolves a special target a runtime string may carry.
  defp emit_mapped(name, %{shape: :warp}, [{:str, target} | _rest] = args, env) do
    case CommandMap.warp_target(target) do
      {:ok, atom_form} -> {["ctx = warp(ctx, #{atom_form})"], :cont}
      :error -> emit_warp(name, args, env)
    end
  end

  defp emit_mapped(name, %{shape: :warp}, args, env), do: emit_warp(name, args, env)

  # `warpwaitingpc "<map>",<x>,<y>{,<n>}` — like `warp` but with coordinates and
  # an optional count. The map target resolves "Random"/"SavePoint" to the
  # atom form; a non-string-literal target stays a stub.
  defp emit_mapped(_name, %{shape: :warp_waitingpc, dsl: dsl}, [{:str, target} | rest], env) do
    dest =
      case CommandMap.warp_target(target) do
        {:ok, atom_form} -> atom_form
        :error -> inspect(target)
      end

    {pre, rest} = hoist_all(rest, env)
    coords = Enum.map_join(rest, ", ", &render(&1, env))
    {pre ++ ["ctx = #{dsl}(ctx, #{dest}, #{coords})"], :cont}
  end

  defp emit_mapped(name, %{shape: :warp_waitingpc}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # `npctalk "<msg>"{,"<npc>"{,<flag>{,<color>}}}` — overhead NPC chat. The bare
  # form speaks as the running NPC in its own view range; the optional tail
  # becomes keyword options. An empty NPC name means the attached NPC (rAthena
  # checks `strlen > 0`) and is dropped, and the `<color>` argument is hoisted
  # then dropped: the `ChatMessage` wire message carries no color.
  defp emit_mapped(_name, %{shape: :npctalk, dsl: dsl}, [text], env) do
    {pre, [text]} = hoist_all([text], env)
    {pre ++ ["ctx = #{dsl}(ctx, #{render(text, env)})"], :cont}
  end

  defp emit_mapped(_name, %{shape: :npctalk, dsl: dsl}, [text, npc | rest], env) do
    {pre, [text, npc | rest]} = hoist_all([text, npc | Enum.take(rest, 2)], env)
    opts = npctalk_npc_opt(npc, env) ++ npctalk_target_opt(rest, env)
    {pre ++ ["ctx = #{dsl}(ctx, #{Enum.join([render(text, env) | opts], ", ")})"], :cont}
  end

  # A single-argument buildin (event ref, NPC name): any other arity is a
  # form the DSL cannot express, so it stays a stub.
  defp emit_mapped(_name, %{shape: :ref1, dsl: dsl}, [arg], env) do
    {pre, [arg]} = hoist_all([arg], env)
    {pre ++ ["ctx = #{dsl}(ctx, #{render(arg, env)})"], :cont}
  end

  defp emit_mapped(name, %{shape: :ref1}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # `initnpctimer`/`stopnpctimer`: no args targets the calling NPC, one arg
  # targets a name; the attach-flag variants have no DSL equivalent yet.
  defp emit_mapped(_name, %{shape: :timer, dsl: dsl}, [], _env),
    do: {["ctx = #{dsl}(ctx)"], :cont}

  defp emit_mapped(_name, %{shape: :timer, dsl: dsl}, [arg], env) do
    {pre, [arg]} = hoist_all([arg], env)
    {pre ++ ["ctx = #{dsl}(ctx, #{render(arg, env)})"], :cont}
  end

  defp emit_mapped(name, %{shape: :timer}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # An effect with one optional argument (`setcart {<type>}`): zero args →
  # the DSL default, one arg → `name(ctx, arg)`; any longer form stays a stub.
  defp emit_mapped(_name, %{shape: :opt1, dsl: dsl}, [], _env),
    do: {["ctx = #{dsl}(ctx)"], :cont}

  defp emit_mapped(_name, %{shape: :opt1, dsl: dsl}, [arg], env) do
    {pre, [arg]} = hoist_all([arg], env)
    {pre ++ ["ctx = #{dsl}(ctx, #{render(arg, env)})"], :cont}
  end

  defp emit_mapped(name, %{shape: :opt1}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  defp emit_mapped(name, %{shape: :item_group_optional, dsl: dsl, args: types}, args, env) do
    {pre, args} = hoist_all(args, env)

    case item_group_optional_args(args, types, env) do
      {:ok, rendered} ->
        {pre ++ ["ctx = #{dsl}(ctx, #{Enum.join(rendered, ", ")})"], :cont}

      :error ->
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
    end
  end

  # `setriding {<n>}`: the bare form mounts; an explicit arg mounts unless it
  # evaluates to 0, which dismounts (rAthena's `setriding 0`).
  defp emit_mapped(_name, %{shape: :riding, dsl: dsl}, [], _env),
    do: {["ctx = #{dsl}(ctx, true)"], :cont}

  defp emit_mapped(_name, %{shape: :riding, dsl: dsl}, [arg], env) do
    {pre, [arg]} = hoist_all([arg], env)
    {pre ++ ["ctx = #{dsl}(ctx, (#{render(arg, env)}) != 0)"], :cont}
  end

  defp emit_mapped(name, %{shape: :riding}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # `monster "<map>",<x>,<y>,"<display name>",<mob>,<amount>{,"<event>"{,<size>{,<ai>}}}`
  # → summon_mob. The display name is cosmetic (the engine renders the db
  # name) and the size/ai tail has no DSL equivalent; both are dropped.
  # `"this"` targets the attached map (the DSL default) and non-positive
  # literal coordinates mean a random walkable cell, both per rAthena.
  defp emit_mapped(_name, %{shape: :monster}, [map, x, y, _display, mob, amount | rest], env) do
    {pre, [map, x, y, mob, amount | rest]} =
      hoist_all([map, x, y, mob, amount | Enum.take(rest, 1)], env)

    parts =
      [monster_mob(mob, env), monster_map(map, env), monster_at(x, y, env)] ++
        monster_amount(amount, env) ++ monster_event(rest, env)

    {pre ++ ["ctx = summon_mob(ctx, #{parts |> List.flatten() |> Enum.join(", ")})"], :cont}
  end

  defp emit_mapped(name, %{shape: :monster}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # `areamonster "<map>",<x1>,<y1>,<x2>,<y2>,"<display name>",<mob>,<amount>{,"<event>"{,...}}}`
  # → summon_mob_area. Same drops as `monster` (display name, size/ai tail);
  # the four coordinates become the `:area` rectangle and `"this"` still maps to
  # the attached map.
  defp emit_mapped(
         _name,
         %{shape: :areamonster},
         [map, x1, y1, x2, y2, _display, mob, amount | rest],
         env
       ) do
    {pre, [map, x1, y1, x2, y2, mob, amount | rest]} =
      hoist_all([map, x1, y1, x2, y2, mob, amount | Enum.take(rest, 1)], env)

    parts =
      [monster_mob(mob, env), monster_map(map, env), area_arg(x1, y1, x2, y2, env)] ++
        monster_amount(amount, env) ++ monster_event(rest, env)

    {pre ++
       ["ctx = summon_mob_area(ctx, #{parts |> List.flatten() |> Enum.join(", ")})"], :cont}
  end

  defp emit_mapped(name, %{shape: :areamonster}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # `navigateto "<map>"{,<x>,<y>,<flag>,<hide_window>,<monster_id>}` — open the
  # client navigation window toward a map coordinate or a tracked monster. The
  # map is required; the trailing args default to (0,0), NAV_KAFRA_AND_AIRSHIP,
  # hidden, and no monster, matching rAthena. `hide_window` folds any nonzero to
  # a bool, and the optional `<char_id>` tail (target another character) is
  # dropped.
  defp emit_mapped(_name, %{shape: :navigateto, dsl: dsl}, [map | rest], env) do
    {pre, [map | rest]} = hoist_all([map | Enum.take(rest, 5)], env)
    [x, y, flag, hide, mob] = pad_nav(rest)

    parts = [
      render(map, env),
      render(x, env),
      render(y, env),
      nav_flag_arg(flag, env),
      nav_hide_arg(hide, env),
      render(mob, env)
    ]

    {pre ++ ["ctx = #{dsl}(ctx, #{Enum.join(parts, ", ")})"], :cont}
  end

  defp emit_mapped(name, %{shape: :navigateto}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # `savepoint "map",x,y{,rx,ry}` — the optional range args are dropped.
  defp emit_mapped(_name, %{shape: :savepoint}, args, env) do
    {pre, [map, x, y | _rest]} = hoist_all(args, env)

    {pre ++
       ["ctx = savepoint(ctx, #{render(map, env)}, #{render(x, env)}, #{render(y, env)})"], :cont}
  end

  # `announce`/`mapannounce`/`areaannounce`/`broadcast`: keep the fixed
  # text/flag prefix and an optional trailing color; rAthena's font tail
  # (fontType/fontSize/fontAlign/fontY) has no DSL equivalent and is dropped.
  defp emit_mapped(_name, %{shape: :announce, dsl: dsl, fixed: fixed}, args, env) do
    {pre, kept} = args |> Enum.take(fixed + 1) |> hoist_all(env)
    rendered = Enum.map_join(kept, ", ", &render(&1, env))
    {pre ++ ["ctx = #{dsl}(ctx, #{rendered})"], :cont}
  end

  # `setnpcdisplay "<npc>",<sprite>` / `"<npc>","<display>"` /
  # `"<npc>","<display>",<sprite>{,<size>}` — the second argument's type
  # (string vs int/name) picks the name-only vs sprite-only 2-arg form. Emits
  # one `set_npc_display(ctx, npc: ..., ...)` keyword call; any other shape
  # stays a stub.
  defp emit_mapped(_name, %{shape: :setnpcdisplay}, args, env) do
    {pre, args} = hoist_all(args, env)

    case build_npc_display(args, env) do
      {:ok, rendered} ->
        {pre ++ ["ctx = set_npc_display(ctx, #{rendered})"], :cont}

      :error ->
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["ctx = todo(ctx, :setnpcdisplay, [#{rendered}])"], :cont}
    end
  end

  # A no-argument effect (`nude`): any trailing rAthena arg (the optional char
  # id) is still hoisted so a side effect in it is preserved, then dropped.
  defp emit_mapped(_name, %{shape: :nullary, dsl: dsl}, args, env) do
    {pre, _args} = hoist_all(args, env)
    {pre ++ ["ctx = #{dsl}(ctx)"], :cont}
  end

  defp emit_mapped(
         _name,
         %{shape: :rentitem3},
         [
           item,
           seconds,
           identify,
           refine,
           attribute,
           card0,
           card1,
           card2,
           card3,
           option_ids,
           option_values,
           option_params
         ],
         env
       ) do
    {pre,
     [
       item,
       seconds,
       _,
       refine,
       _,
       card0,
       card1,
       card2,
       card3,
       option_ids,
       option_values,
       option_params
     ]} =
      hoist_all(
        [
          item,
          seconds,
          identify,
          refine,
          attribute,
          card0,
          card1,
          card2,
          card3,
          option_ids,
          option_values,
          option_params
        ],
        env
      )

    options = rental_random_options(option_ids, option_values, option_params, env)

    call =
      "ctx = give_item_rental(ctx, #{typed_arg(item, :item, env)}, " <>
        "#{typed_arg(seconds, :int, env)}, refine: #{render(refine, env)}, " <>
        "card0: #{render(card0, env)}, card1: #{render(card1, env)}, " <>
        "card2: #{render(card2, env)}, card3: #{render(card3, env)}, " <>
        "random_options: #{options})"

    {pre ++ [call], :cont}
  end

  defp emit_mapped(name, %{shape: :rentitem3}, args, env) do
    {pre, args} = hoist_all(args, env)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
  end

  # Trailing/optional buildin args beyond the declared arity (e.g. `emotion`'s
  # target) are dropped, not padded onto the DSL call; all args are still
  # hoisted first so any side effect in a dropped arg is preserved.
  # `questinfo <Icon>{,<Map Mark Color>{,"<condition>"}}` — an OnInit-only
  # registration. The icon/mark-color constants resolve to their client ints;
  # a string-literal condition transpiles into a `(ctx -> boolean)` predicate
  # closure. A dynamic (non-literal) condition, an unknown icon/color constant,
  # or an unexpected arity stays a stub.
  defp emit_mapped(name, %{shape: :questinfo, dsl: dsl}, args, env) do
    case questinfo_call(dsl, args, env) do
      {:ok, line} ->
        {[line], :cont}

      :error ->
        {pre, args} = hoist_all(args, env)
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
    end
  end

  defp emit_mapped(_name, %{dsl: dsl, args: types}, args, env) do
    {pre, args} = hoist_all(args, env)

    rendered =
      args
      |> Enum.take(length(types))
      |> Enum.zip(types)
      |> Enum.map(fn {arg, type} -> typed_arg(arg, type, env) end)

    {pre ++ ["ctx = #{dsl}(ctx, #{Enum.join(rendered, ", ")})"], :cont}
  end

  defp emit_warp(name, args, env) do
    {pre, args} = hoist_all(args, env)

    case args do
      [map, x, y] ->
        call = "ctx = warp(ctx, #{render(map, env)}, #{render(x, env)}, #{render(y, env)})"
        {pre ++ [call], :cont}

      _ ->
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {pre ++ ["ctx = todo(ctx, #{atom_lit(name)}, [#{rendered}])"], :cont}
    end
  end

  defp questinfo_call(dsl, [icon], _env) do
    with {:ok, icon_v} <- quest_const(@quest_icons, icon) do
      {:ok, "ctx = #{dsl}(ctx, #{icon_v})"}
    end
  end

  defp questinfo_call(dsl, [icon, color], _env) do
    with {:ok, icon_v} <- quest_const(@quest_icons, icon),
         {:ok, color_v} <- quest_const(@quest_marks, color) do
      {:ok, "ctx = #{dsl}(ctx, #{icon_v}, #{color_v})"}
    end
  end

  defp questinfo_call(dsl, [icon, color, {:str, condition}], env) do
    with {:ok, icon_v} <- quest_const(@quest_icons, icon),
         {:ok, color_v} <- quest_const(@quest_marks, color),
         {:ok, closure} <- questinfo_condition(condition, env) do
      {:ok, "ctx = #{dsl}(ctx, #{icon_v}, #{color_v}, #{closure})"}
    end
  end

  defp questinfo_call(_dsl, _args, _env), do: :error

  # An icon/mark argument is a named constant (`QTYPE_QUEST`) or a raw int.
  defp quest_const(_table, {:int, n}), do: {:ok, to_string(n)}

  defp quest_const(table, {:name, s}) do
    case Map.fetch(table, String.upcase(s)) do
      {:ok, v} -> {:ok, to_string(v)}
      :error -> :error
    end
  end

  defp quest_const(_table, _arg), do: :error

  # `npctalk`'s optional NPC name: an empty literal means the attached NPC,
  # which is the DSL default, so it is dropped.
  defp npctalk_npc_opt({:str, ""}, _env), do: []
  defp npctalk_npc_opt(npc, env), do: ["npc: #{render(npc, env)}"]

  # `npctalk`'s optional `bc_*` target: an int literal or a `bc_*` constant
  # resolves to the DSL scope atom, anything dynamic is passed through as the
  # integer the DSL decodes at runtime. The trailing `<color>` argument
  # (already hoisted) is dropped.
  defp npctalk_target_opt([], _env), do: []

  defp npctalk_target_opt([flag | _color], env),
    do: ["target: #{npctalk_target(flag, env)}"]

  defp npctalk_target({:int, value}, _env), do: inspect(Flags.scope(value, :area))

  defp npctalk_target({:name, symbol} = expr, env) do
    case Flags.value(symbol) do
      {:ok, value} -> inspect(Flags.scope(value, :area))
      :error -> render(expr, env)
    end
  end

  defp npctalk_target(expr, env), do: render(expr, env)

  # `navigateto` trailing args: pad the optional x/y/flag/hide_window/monster_id
  # with their rAthena defaults (0,0,NAV_KAFRA_AND_AIRSHIP,hidden,no monster).
  defp pad_nav(args) do
    defaults = [{:int, 0}, {:int, 0}, {:name, "NAV_KAFRA_AND_AIRSHIP"}, {:int, 1}, {:int, 0}]

    defaults
    |> Enum.with_index()
    |> Enum.map(fn {default, i} -> Enum.at(args, i, default) end)
  end

  # A NAV_* flag resolves through `@nav_flags`; a raw int renders as-is.
  defp nav_flag_arg({:name, symbol}, _env) do
    case Map.fetch(@nav_flags, String.upcase(symbol)) do
      {:ok, value} -> to_string(value)
      :error -> const_todo(symbol)
    end
  end

  defp nav_flag_arg(arg, env), do: render(arg, env)

  defp nav_hide_arg({:int, 0}, _env), do: "false"
  defp nav_hide_arg({:int, _nonzero}, _env), do: "true"
  defp nav_hide_arg({:neg, {:int, _nonzero}}, _env), do: "true"
  defp nav_hide_arg(arg, env), do: "(#{render(arg, env)}) != 0"

  # Transpiles a questinfo condition string (rAthena parses it as its own
  # script expression) into a `(ctx -> boolean)` closure, reusing the standard
  # expression codegen. Parsed via a `set` wrapper so the whole string is read
  # as one expression. Anything that fails to parse stays a stub.
  defp questinfo_condition(condition, env) do
    case Parser.parse_body("set .@qicond, " <> condition <> ";") do
      {:ok, [{:assign, _target, cond_ast}]} ->
        {:ok, "fn ctx -> #{cond_str(cond_ast, env)} end"}

      _ ->
        :error
    end
  end

  defp rental_random_options(option_ids, option_values, option_params, env) do
    ids = read_var(option_ids, "[]", env)
    values = read_var(option_values, "[]", env)
    params = read_var(option_params, "[]", env)

    "Map.new(Enum.zip([#{ids}, #{values}, #{params}]), " <>
      "fn {id, val, parm} -> {to_string(id), %{val: val, parm: parm}} end)"
  end

  defp monster_mob({:int, id}, _env), do: "mob_id: #{id}"
  defp monster_mob({:name, aegis}, _env), do: "mob_name: #{inspect(aegis)}"
  defp monster_mob({:str, aegis}, _env), do: "mob_name: #{inspect(aegis)}"
  defp monster_mob(expr, env), do: "mob_id: #{render(expr, env)}"

  defp monster_map({:str, "this"}, _env), do: []
  defp monster_map(map, env), do: "map: #{render_str(map, env)}"

  defp monster_at(x, y, env) do
    case {literal_coord(x), literal_coord(y)} do
      {xi, yi} when is_integer(xi) and is_integer(yi) and (xi <= 0 or yi <= 0) -> "at: :random"
      _ -> "at: {#{render(x, env)}, #{render(y, env)}}"
    end
  end

  defp area_arg(x1, y1, x2, y2, env),
    do: "area: {#{render(x1, env)}, #{render(y1, env)}, #{render(x2, env)}, #{render(y2, env)}}"

  defp literal_coord({:int, n}), do: n
  defp literal_coord({:neg, {:int, n}}), do: -n
  defp literal_coord(_expr), do: nil

  defp monster_amount({:int, 1}, _env), do: []
  defp monster_amount(amount, env), do: ["amount: #{render(amount, env)}"]

  defp monster_event([], _env), do: []
  defp monster_event([{:str, ""}], _env), do: []
  defp monster_event([event], env), do: ["event: #{render_str(event, env)}"]

  # `setnpcdisplay` disambiguation (see the emit_mapped clause): the second
  # argument's type — string literal vs sprite (int or sprite name constant) —
  # selects the name-only vs sprite-only 2-arg form. Sprite name constants
  # (`4_M_THIEF_RUMIN`) resolve through the `e_job_types` sprite table threaded
  # into `env.sprites`; an unresolved constant stays a stub.
  defp build_npc_display([npc, {:str, display}], env) do
    {:ok, "npc: #{render(npc, env)}, display_name: #{inspect(display)}"}
  end

  defp build_npc_display([npc, sprite], env) do
    with {:ok, sprite_v} <- sprite_arg(sprite, env) do
      {:ok, "npc: #{render(npc, env)}, sprite: #{sprite_v}"}
    end
  end

  defp build_npc_display([npc, {:str, display}, sprite], env) do
    with {:ok, sprite_v} <- sprite_arg(sprite, env) do
      {:ok, "npc: #{render(npc, env)}, display_name: #{inspect(display)}, sprite: #{sprite_v}"}
    end
  end

  defp build_npc_display([npc, {:str, display}, sprite, size], env) do
    with {:ok, sprite_v} <- sprite_arg(sprite, env) do
      {:ok,
       "npc: #{render(npc, env)}, display_name: #{inspect(display)}, sprite: #{sprite_v}, " <>
         "size: #{render(size, env)}"}
    end
  end

  defp build_npc_display(_args, _env), do: :error

  defp sprite_arg({:int, n}, _env), do: {:ok, to_string(n)}

  defp sprite_arg({:name, s}, env) do
    case Map.fetch(env.sprites, s) do
      {:ok, id} -> {:ok, Integer.to_string(id)}
      :error -> :error
    end
  end

  defp sprite_arg(expr, env), do: {:ok, render(expr, env)}

  defp typed_arg({:int, n}, _type, _env), do: to_string(n)

  defp typed_arg(arg, :item, env) do
    case arg do
      {:str, s} -> resolve_or_const(&Resolver.item/1, s)
      {:name, s} -> resolve_or_const(&Resolver.item/1, s)
      other -> render(other, env)
    end
  end

  defp typed_arg({:name, symbol}, :item_group, _env) do
    case Resolver.item_group(symbol) do
      {:ok, key} -> inspect(key)
      :error -> const_todo(symbol)
    end
  end

  defp typed_arg(arg, :item_group, env), do: render(arg, env)

  # A skill name the catalog doesn't know (an unimplemented skill) falls back
  # to its atom form rather than a raising const stub: the DSL answers `0`
  # for an unknown skill atom, which is exactly its level on this server.
  defp typed_arg(arg, :skill, env) do
    case arg do
      {:str, s} -> skill_arg(s)
      {:name, s} -> skill_arg(s)
      other -> render(other, env)
    end
  end

  defp typed_arg({:name, s}, :status, _env) do
    case Resolver.status(s) do
      {:ok, atom} -> inspect(atom)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :emote, _env) do
    case Resolver.emote(s) do
      {:ok, atom} -> inspect(atom)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :effect, _env) do
    case Resolver.effect(s) do
      {:ok, atom} when is_atom(atom) -> inspect(atom)
      {:ok, id} -> to_string(id)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :quest_mode, _env) do
    case Resolver.quest_mode(s) do
      {:ok, atom} -> inspect(atom)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :bound, _env) do
    case Resolver.bound(s) do
      {:ok, value} -> to_string(value)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :equip_slot, _env) do
    case Resolver.equip_slot(s) do
      {:ok, idx} -> to_string(idx)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :look, _env) do
    case Resolver.look(s) do
      {:ok, id} -> to_string(id)
      :error -> const_todo(s)
    end
  end

  defp typed_arg({:name, s}, :cell_type, _env) do
    case Resolver.cell_type(s) do
      {:ok, atom} -> ":" <> Atom.to_string(atom)
      :error -> const_todo(s)
    end
  end

  defp typed_arg(arg, :string, env), do: render_str(arg, env)
  defp typed_arg(arg, :skill_opts, env), do: render(arg, env)
  defp typed_arg(arg, _type, env), do: render(arg, env)

  defp resolve_or_const(resolver, symbol) do
    case resolver.(symbol) do
      {:ok, value} -> to_string(value)
      :error -> const_todo(symbol)
    end
  end

  defp skill_arg(symbol) do
    case Resolver.skill(symbol) do
      {:ok, id} -> to_string(id)
      :error -> inspect(String.to_atom(String.downcase(symbol)))
    end
  end

  defp const_todo(symbol) do
    flag(:todo_mod)
    "Todo.const!(#{inspect(String.to_atom(symbol))})"
  end

  # -- switch ------------------------------------------------------------------

  defp emit_switch(expr, clauses, env) do
    {pre, expr} = hoist(expr, env)
    id = next_id()

    {value_pre, effective} =
      clauses |> effective_clauses(env) |> default_last() |> bind_clause_values(env)

    nested_break? = Enum.any?(effective, fn {_, stmts} -> nested_break?(stmts) end)

    clause_env =
      if nested_break?,
        do: %{env | break: {:throw, "brk_#{id}"}},
        else: %{env | break: :plain}

    {clause_lines, terminals} =
      effective
      |> Enum.map(fn {values, stmts} ->
        {lines, terminal} = emit_block(strip_trailing_break(stmts), clause_env)
        {clause_head(values, env) ++ branch_body(lines, terminal), terminal}
      end)
      |> Enum.unzip()

    default? = Enum.any?(effective, fn {values, _} -> :default in values end)
    catch_all = if default?, do: [], else: ["_ -> ctx"]

    {tmp, bindings} =
      case expr do
        {:temp, name} -> {name, []}
        _ -> tmp_var() |> then(fn t -> {t, ["#{t} = #{render(expr, env)}", ""]} end)
      end

    case_lines = ["case #{tmp} do"] ++ List.flatten(clause_lines) ++ catch_all ++ ["end"]
    terminal = if Enum.all?(terminals, &(&1 == :stop)) and default?, do: :stop, else: :cont

    {pre ++ value_pre ++ bindings ++ switch_body(case_lines, nested_break?, terminal, id),
     terminal}
  end

  # An all-stop switch (every clause exits, default present) yields no value
  # anything could read; binding it would leave a dead `ctx =`.
  defp switch_body(case_lines, true, :stop, id),
    do: ["try do"] ++ case_lines ++ ["catch", ":throw, {:brk_#{id}, ctx} -> ctx", "end"]

  defp switch_body(case_lines, true, :cont, id),
    do: ["ctx =", "try do"] ++ case_lines ++ ["catch", ":throw, {:brk_#{id}, ctx} -> ctx", "end"]

  defp switch_body(case_lines, false, :stop, _id), do: case_lines
  defp switch_body(case_lines, false, :cont, _id), do: ["ctx ="] ++ case_lines

  # rAthena matches switch values against their cases before the default no
  # matter where `default:` sits in the source; Elixir's `case` matches top
  # down, so a leading `default:` must sink to the end or its `_ ->` shadows
  # every later clause. Runs after fall-through materialization, which has
  # already merged each clause's continuation, so reordering is safe.
  defp default_last(clauses) do
    {defaults, rest} = Enum.split_with(clauses, fn {values, _} -> :default in values end)
    rest ++ defaults
  end

  # A switch clause value that renders as a call (`case EQI_ACC_L:` where the
  # name is a var read, not a resolvable constant) cannot appear inside a case
  # guard; bind each one to a temp above the case and guard against the temp.
  # Literal ints/strings and resolvable constants stay inline.
  defp bind_clause_values(clauses, env) do
    {clauses, pre} =
      Enum.map_reduce(clauses, [], fn {values, stmts}, pre ->
        {values, pre} = Enum.map_reduce(values, pre, &bind_clause_value(&1, &2, env))
        {{values, stmts}, pre}
      end)

    {pre, clauses}
  end

  defp bind_clause_value(value, pre, env) do
    if value == :default or guard_safe_value?(value) do
      {value, pre}
    else
      {vpre, value} = hoist(value, env)
      tmp = tmp_var()
      {{:temp, tmp}, pre ++ vpre ++ ["#{tmp} = #{render(value, env)}"]}
    end
  end

  defp guard_safe_value?({:int, _}), do: true
  defp guard_safe_value?({:neg, {:int, _}}), do: true
  defp guard_safe_value?({:str, _}), do: true
  defp guard_safe_value?({:temp, _}), do: true

  defp guard_safe_value?({:name, name}),
    do: read_name(name) == :error and match?({:ok, _}, Resolver.constant(name))

  defp guard_safe_value?(_value), do: false

  # C fall-through: a clause body that does not end the flow continues into
  # the next clause's body; materialize that by appending it.
  defp effective_clauses(clauses, _env) do
    clauses
    |> Enum.reverse()
    |> Enum.reduce([], fn {values, stmts}, acc ->
      stmts =
        if falls_through?(stmts) and acc != [] do
          {_, next_stmts} = hd(acc)
          stmts ++ next_stmts
        else
          stmts
        end

      [{values, stmts} | acc]
    end)
  end

  defp falls_through?(stmts) do
    case List.last(stmts) do
      {:break} -> false
      {:cmd, c, _} when c in ["close", "end"] -> false
      {:goto, _} -> false
      {:menu, _} -> false
      {:return, _} -> false
      _ -> true
    end
  end

  defp strip_trailing_break(stmts) do
    case List.last(stmts) do
      {:break} -> Enum.drop(stmts, -1)
      _ -> stmts
    end
  end

  # break below the clause's top level (inside if/blocks) needs a throw;
  # nested loops and switches own their breaks.
  defp nested_break?(stmts), do: Enum.any?(stmts, &stmt_has_nested_break?/1)

  defp stmt_has_nested_break?({:if, _, t, e}),
    do: has_break?(t) or has_break?(e)

  defp stmt_has_nested_break?({:block, stmts}), do: has_break?(stmts)
  defp stmt_has_nested_break?(_), do: false

  defp has_break?(stmts) do
    Enum.any?(stmts, fn
      {:break} -> true
      {:if, _, t, e} -> has_break?(t) or has_break?(e)
      {:block, b} -> has_break?(b)
      _ -> false
    end)
  end

  defp clause_head(values, env) do
    ints = Enum.filter(values, &match?({:int, _}, &1))

    cond do
      :default in values ->
        ["_ ->"]

      length(ints) == length(values) and length(ints) == 1 ->
        ["#{render(hd(ints), env)} ->"]

      length(ints) == length(values) ->
        ["v when v in [#{Enum.map_join(ints, ", ", &render(&1, env))}] ->"]

      true ->
        guards = Enum.map_join(values, " or ", fn v -> "v == #{render(v, env)}" end)
        ["v when #{guards} ->"]
    end
  end

  # -- loops -------------------------------------------------------------------

  defp emit_loop(kind, cond_expr, step, body, env) do
    id = next_id()
    fname = "loop_#{id}"
    needs_try = loop_needs_try?(body)

    loop_env =
      if needs_try do
        %{env | break: {:throw, "brk_#{id}"}, loop: {:throw, "cont_#{id}"}}
      else
        %{env | break: :plain, loop: :plain}
      end

    {body_lines, terminal} = emit_block(body, loop_env)
    {step_lines, :cont} = emit_block(step, env)

    # A blocking call in the condition (`while(input(...))`, `while(select(...))`)
    # hoists into `cond_pre`, placed where the condition evaluates — the loop
    # function's head for `while`, the after-body check for `do_while` — so it
    # re-runs on every iteration.
    {cond_pre, cond_expr} = hoist(cond_expr, env)
    cond_s = cond_str(cond_expr, env)

    # What runs when an iteration completes: while loops step and recurse
    # (the condition guards the body); do-while recurses conditionally.
    recurse = "#{fname}(ctx#{helper_call(env)})"

    on_next =
      case kind do
        :while -> step_lines ++ [recurse]
        :do_while -> cond_pre ++ ["if #{cond_s} do", recurse, "else", "ctx", "end"]
      end

    body = loop_body(body_lines, terminal, on_next, needs_try, id)

    inner =
      case kind do
        # `while(1)` (rAthena's idiomatic infinite loop) has a constant-true
        # guard: the body runs unconditionally and only `break`/`close`/`end`
        # exits it, so emitting `if true do … else ctx end` would leave a dead
        # `else` branch. Drop the guard and emit the body straight.
        :while when cond_s == "true" -> cond_pre ++ body
        :while -> cond_pre ++ ["if #{cond_s} do"] ++ body ++ ["else", "ctx", "end"]
        :do_while -> body
      end

    defer("""
    defp #{fname}(#{helper_params(inner, env)}) do
      #{join_body(inner)}
    end
    """)

    {["ctx = #{fname}(ctx#{helper_call(env)})"], :cont}
  end

  defp loop_body(body_lines, terminal, on_next, false = _needs_try, _id) do
    case terminal do
      :break -> body_lines ++ ["ctx"]
      :stop -> body_lines
      _ -> body_lines ++ on_next
    end
  end

  defp loop_body(body_lines, terminal, on_next, true = _needs_try, id) do
    wrapped =
      case terminal do
        :stop -> body_lines
        :break -> body_lines ++ ["{:done, ctx}"]
        _ -> body_lines ++ ["{:next, ctx}"]
      end

    ["result ="] ++
      ["try do"] ++
      wrapped ++
      [
        "catch",
        ":throw, {:brk_#{id}, ctx} -> {:done, ctx}",
        ":throw, {:cont_#{id}, ctx} -> {:next, ctx}",
        "end",
        "",
        "case result do",
        "{:next, ctx} -> " <> Enum.join(on_next, "\n")
      ] ++
      ["{:done, ctx} -> ctx", "end"]
  end

  defp loop_needs_try?(body) do
    Enum.any?(body, fn
      {:break} -> false
      {:continue} -> false
      stmt -> stmt_reaches_loop_ctl?(stmt)
    end)
  end

  defp stmt_reaches_loop_ctl?({:if, _, t, e}), do: any_loop_ctl?(t) or any_loop_ctl?(e)
  defp stmt_reaches_loop_ctl?({:block, b}), do: any_loop_ctl?(b)

  defp stmt_reaches_loop_ctl?({:switch, _, clauses}),
    do: Enum.any?(clauses, fn {_, stmts} -> any_continue?(stmts) end)

  defp stmt_reaches_loop_ctl?(_), do: false

  defp any_loop_ctl?(stmts) do
    Enum.any?(stmts, fn
      {:break} -> true
      {:continue} -> true
      stmt -> stmt_reaches_loop_ctl?(stmt)
    end)
  end

  # switch absorbs break but continue passes through to the loop
  defp any_continue?(stmts) do
    Enum.any?(stmts, fn
      {:continue} -> true
      {:if, _, t, e} -> any_continue?(t) or any_continue?(e)
      {:block, b} -> any_continue?(b)
      {:switch, _, clauses} -> Enum.any?(clauses, fn {_, s} -> any_continue?(s) end)
      _ -> false
    end)
  end

  # -- assignment --------------------------------------------------------------

  defp emit_assign({:name, "Zeny"}, {:bin, :-, {:name, "Zeny"}, amount}, env) do
    {pre, amount} = hoist(amount, env)
    {pre ++ ["ctx = pay_zeny(ctx, #{render(amount, env)})"], :cont}
  end

  defp emit_assign({:name, "Zeny"}, {:bin, :+, {:name, "Zeny"}, amount}, env) do
    {pre, amount} = hoist(amount, env)
    {pre ++ ["ctx = credit_zeny(ctx, #{render(amount, env)})"], :cont}
  end

  # `set getd("<name>"),<value>` is rAthena's long form of `setd`: the target
  # is a runtime-built variable name.
  defp emit_assign({:call, "getd", [name]}, expr, env) do
    {pre, [name, expr]} = hoist_all([name, expr], env)
    {pre ++ ["ctx = setd(ctx, #{render(name, env)}, #{render(expr, env)})"], :cont}
  end

  # `set getvariableofnpc(.var, "<npc>"), <value>` writes another NPC's `.`
  # variable. Only a plain `.` var is writable this way; an indexed or dynamic
  # ref stays a stub.
  defp emit_assign({:call, "getvariableofnpc", [var_ref, npc_name]}, expr, env) do
    {pre, expr} = hoist(expr, env)

    case npc_var_of_key(var_ref) do
      {:ok, key} ->
        {pre ++
           [
             "ctx = set_npc_var_of(ctx, #{key}, #{render_str(npc_name, env)}, #{render(expr, env)})"
           ], :cont}

      :error ->
        flag(:todo_fun)

        {pre ++
           [
             "ctx = todo(ctx, :getvariableofnpc, [#{render(var_ref, env)}, #{render_str(npc_name, env)}, #{render(expr, env)}])"
           ], :cont}
    end
  end

  defp emit_assign(target, expr, env) do
    {pre, expr} = hoist(expr, env)

    lines =
      case target do
        {:var, _, _, _} ->
          [set_var(target, render(expr, env), env)]

        {:name, name} ->
          case CommandMap.read(name) do
            {:ok, _} ->
              flag(:todo_fun)
              ["ctx = todo(ctx, :set_param, [#{inspect(name)}, #{render(expr, env)}])"]

            :error ->
              [set_var(target, render(expr, env), env)]
          end

        {:index, base, index} ->
          flag(:rathena)

          [
            set_var(
              base,
              "Rathena.put_at(#{read_var(base, "[]", env)}, #{render(index, env)}, " <>
                "#{render(expr, env)}, #{pad_default(base)})",
              env
            )
          ]

        other ->
          flag(:todo_fun)
          ["ctx = todo(ctx, :assign, [#{inspect(inspect(other))}, #{render(expr, env)}])"]
      end

    {pre ++ lines, :cont}
  end

  # Writes routed by scope: local → ctx map, session → player session,
  # bare name → permanent char var, everything else → stub.
  defp set_var({:var, :local, name, type}, value, _env),
    do: "ctx = set_local(ctx, #{var_key(name, type)}, #{value})"

  defp set_var({:var, :session, name, type}, value, _env),
    do: "ctx = set_temp_var(ctx, #{var_key(name, type)}, #{value})"

  defp set_var({:var, :server, name, type}, value, _env),
    do: "ctx = set_server_var(ctx, #{scope_var_key(name, type)}, #{value})"

  defp set_var({:var, :server_temp, name, type}, value, _env),
    do: "ctx = set_server_temp_var(ctx, #{scope_var_key(name, type)}, #{value})"

  defp set_var({:var, :account, name, type}, value, _env),
    do: "ctx = set_account_var(ctx, #{scope_var_key("#" <> name, type)}, #{value})"

  defp set_var({:var, :account_global, name, type}, value, _env),
    do: "ctx = set_account_var(ctx, #{scope_var_key("##" <> name, type)}, #{value})"

  defp set_var({:var, :npc, name, type}, value, _env),
    do: "ctx = set_npc_var(ctx, #{scope_var_key(name, type)}, #{value})"

  # Instance scope (') has no store yet: no instance system exists.
  defp set_var({:var, :instance, name, type}, value, _env) do
    flag(:todo_fun)
    "ctx = todo(ctx, :set_var, [#{scope_var_key("'" <> name, type)}, #{value}])"
  end

  defp set_var({:name, name}, value, _env),
    do: "ctx = set_char_var(ctx, #{inspect(String.to_atom(name))}, #{value})"

  defp set_var(other, value, _env),
    do: "ctx = todo(ctx, :dynamic_var, [#{inspect(inspect(other))}, #{value}])"

  defp read_var({:var, :local, name, type}, default, _env),
    do: "get_local(ctx, #{var_key(name, type)}, #{default})"

  defp read_var({:var, :session, name, type}, default, _env),
    do: "get_temp_var(ctx, #{var_key(name, type)}, #{default})"

  defp read_var({:var, :server, name, type}, default, _env),
    do: "get_server_var(ctx, #{scope_var_key(name, type)}, #{default})"

  defp read_var({:var, :server_temp, name, type}, default, _env),
    do: "get_server_temp_var(ctx, #{scope_var_key(name, type)}, #{default})"

  defp read_var({:var, :account, name, type}, default, _env),
    do: "get_account_var(ctx, #{scope_var_key("#" <> name, type)}, #{default})"

  defp read_var({:var, :account_global, name, type}, default, _env),
    do: "get_account_var(ctx, #{scope_var_key("##" <> name, type)}, #{default})"

  defp read_var({:var, :npc, name, type}, default, _env),
    do: "get_npc_var(ctx, #{scope_var_key(name, type)}, #{default})"

  # Instance scope (') has no store yet: no instance system exists.
  defp read_var({:var, :instance, name, type}, _default, _env) do
    flag(:todo_mod)
    "Todo.call!(:get_var, [#{scope_var_key("'" <> name, type)}])"
  end

  defp read_var({:name, name}, default, _env),
    do: "get_char_var(ctx, #{inspect(String.to_atom(name))}, #{default})"

  # Dynamic variable references (getd/setd and friends) have no static name.
  defp read_var(other, _default, _env) do
    flag(:todo_mod)
    "Todo.call!(:dynamic_var, [#{inspect(inspect(other))}])"
  end

  defp var_key(name, :str), do: inspect(String.to_atom(name <> "$"))
  defp var_key(name, _), do: inspect(String.to_atom(name))

  # String key literal for the shared scopes ($, $@, #/##, .), which store
  # string-keyed values rather than atoms. rAthena's trailing `$` marks a
  # string var, keeping `$foo` (int) and `$foo$` (string) distinct.
  defp scope_var_key(name, :str), do: inspect(name <> "$")
  defp scope_var_key(name, _), do: inspect(name)

  defp pad_default({:var, _, _, :str}), do: ~s("")
  defp pad_default({:name, name}), do: if(String.ends_with?(name, "$"), do: ~s(""), else: "0")
  defp pad_default(_), do: "0"

  defp str_target?({:var, _, _, :str}), do: true
  defp str_target?({:name, name}), do: String.ends_with?(name, "$")
  defp str_target?(_), do: false

  # -- hoisting ----------------------------------------------------------------

  # Pulls blocking/effectful subexpressions (select, callfunc, local function
  # calls, postfix ++/--) out of an expression into `{ctx, vN} =` bindings so
  # rendering stays pure. Returns {pre_lines, expr'}.
  defp hoist(nil, _env), do: {[], nil}

  defp hoist(expr, env) do
    {expr, pre} = hoist_walk(expr, env, [])
    {Enum.reverse(pre), expr}
  end

  defp hoist_all(exprs, env) do
    {pres, exprs} =
      Enum.reduce(exprs, {[], []}, fn expr, {pres, acc} ->
        {pre, expr} = hoist(expr, env)
        {pres ++ pre, acc ++ [expr]}
      end)

    {pres, exprs}
  end

  defp hoist_walk({:call, select, args}, env, pre) when select in ["select", "prompt"] do
    {args, pre} = hoist_list(args, env, pre)
    tmp = tmp_var()
    {{:temp, tmp}, ["{ctx, #{tmp}} = select(ctx, #{options(args, env)})" | pre]}
  end

  # Same resolution order as the statement form: a CommandMap-mapped read
  # wins over a generated helper target.
  defp hoist_walk({:call, "callfunc", [{:str, fname} | args]}, env, pre) do
    {args, pre} = hoist_list(args, env, pre)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    tmp = tmp_var()

    case CommandMap.function(fname) do
      {:ok, %{kind: :read, dsl: dsl}} ->
        {{:temp, tmp}, ["#{tmp} = #{read_fn_call(dsl, args, rendered)}" | pre]}

      _command_map ->
        case helper_target(env, fname, rendered) do
          {:ok, call} ->
            {{:temp, tmp}, ["{ctx, #{tmp}} = #{call}" | pre]}

          :missing ->
            flag(:todo_mod)

            {{:temp, tmp},
             ["#{tmp} = Todo.call!(:callfunc, [#{inspect(fname)}, #{rendered}])" | pre]}
        end
    end
  end

  defp hoist_walk({:call, "callsub", [{:name, label} | args]}, env, pre) do
    {args, pre} = hoist_list(args, env, pre)
    rendered = Enum.map_join(args, ", ", &render(&1, env))
    tmp = tmp_var()
    {{:temp, tmp}, ["{ctx, #{tmp}} = #{fn_name(env, label)}(ctx, [#{rendered}])" | pre]}
  end

  # `input(<var>{,<min>{,<max>}})` in expression position: rAthena returns a
  # range status (0 in range, 1 below min, 2 above max) while writing the
  # clamped entry back to the var. The status temp becomes the expression.
  defp hoist_walk({:call, "input", [target | bounds]}, env, pre) do
    {status, lines} = input_lines(target, bounds, env)
    {{:temp, status}, Enum.reverse(lines) ++ pre}
  end

  # `attachrid(account_id{,force})` in expression position: hoist the
  # re-attachment into a `{ctx, success}` binding so the success flag (1/0) is
  # the expression's value.
  defp hoist_walk({:call, "attachrid", args}, env, pre) do
    {args, pre} = hoist_list(args, env, pre)
    tmp = tmp_var()

    case args do
      [account_id] ->
        {{:temp, tmp}, ["{ctx, #{tmp}} = attachrid(ctx, #{render(account_id, env)})" | pre]}

      [account_id, force] ->
        {{:temp, tmp},
         [
           "{ctx, #{tmp}} = attachrid(ctx, #{render(account_id, env)}, #{render(force, env)})"
           | pre
         ]}

      _other ->
        flag(:todo_mod)
        rendered = Enum.map_join(args, ", ", &render(&1, env))
        {{:temp, tmp}, ["#{tmp} = Todo.call!(:attachrid, [#{rendered}])" | pre]}
    end
  end

  defp hoist_walk({:call, name, args}, env, pre) do
    case CommandMap.call_read(name) do
      {:ok, %{shape: :item_group_optional, dsl: dsl, args: types}} ->
        {args, pre} = hoist_list(args, env, pre)
        tmp = tmp_var()

        case item_group_optional_args(args, types, env) do
          {:ok, rendered} ->
            {{:temp, tmp}, ["#{tmp} = #{dsl}(ctx, #{Enum.join(rendered, ", ")})" | pre]}

          :error ->
            flag(:todo_mod)
            rendered = Enum.map_join(args, ", ", &render(&1, env))
            {{:temp, tmp}, ["#{tmp} = Todo.call!(#{atom_lit(name)}, [#{rendered}])" | pre]}
        end

      _other ->
        hoist_regular_call(name, args, env, pre)
    end
  end

  defp hoist_walk({:post_inc, target}, env, pre), do: hoist_postfix(target, "+", env, pre)
  defp hoist_walk({:post_dec, target}, env, pre), do: hoist_postfix(target, "-", env, pre)

  defp hoist_walk({:bin, op, l, r}, env, pre) do
    {l, pre} = hoist_walk(l, env, pre)
    {r, pre} = hoist_walk(r, env, pre)
    {{:bin, op, l, r}, pre}
  end

  defp hoist_walk({:ternary, c, t, f}, env, pre) do
    {c, pre} = hoist_walk(c, env, pre)
    {t, pre} = hoist_walk(t, env, pre)
    {f, pre} = hoist_walk(f, env, pre)
    {{:ternary, c, t, f}, pre}
  end

  defp hoist_walk({:index, b, i}, env, pre) do
    {b, pre} = hoist_walk(b, env, pre)
    {i, pre} = hoist_walk(i, env, pre)
    {{:index, b, i}, pre}
  end

  defp hoist_walk({:neg, e}, env, pre) do
    {e, pre} = hoist_walk(e, env, pre)
    {{:neg, e}, pre}
  end

  defp hoist_walk({:not, e}, env, pre) do
    {e, pre} = hoist_walk(e, env, pre)
    {{:not, e}, pre}
  end

  defp hoist_walk({:bnot, e}, env, pre) do
    {e, pre} = hoist_walk(e, env, pre)
    {{:bnot, e}, pre}
  end

  defp hoist_walk(leaf, _env, pre), do: {leaf, pre}

  defp hoist_regular_call(name, args, env, pre) do
    if MapSet.member?(env.a.local_functions, name) do
      {args, pre} = hoist_list(args, env, pre)
      rendered = Enum.map_join(args, ", ", &render(&1, env))
      tmp = tmp_var()
      {{:temp, tmp}, ["{ctx, #{tmp}} = #{local_fn_name(name)}(ctx, [#{rendered}])" | pre]}
    else
      {args, pre} = hoist_list(args, env, pre)
      {{:call, name, args}, pre}
    end
  end

  # A global read function (`F_CanChangeJob`, `F_GetNumSuffix`) as an expression:
  # the zero-arg form calls `dsl(ctx)`, an arg-bearing one `dsl(ctx, args…)`.
  defp read_fn_call(dsl, [], _rendered), do: "#{dsl}(ctx)"
  defp read_fn_call(dsl, _args, rendered), do: "#{dsl}(ctx, #{rendered})"

  # Shared codegen for `input <var>,<min>{,<max>}`: reads a value, clamps/length-
  # checks it into range (rAthena `Rathena.input_int/3` / `input_str/3`), and
  # writes the clamped value back to the var. Returns {status_temp, lines} in
  # execution order; the status temp is only used in expression position.
  defp input_lines(target, bounds, env, status \\ nil) do
    kind = if str_target?(target), do: ":string", else: ":int"
    helper = if str_target?(target), do: "input_str", else: "input_int"
    {min, max} = input_bounds(bounds, env)
    raw = tmp_var()
    status = status || tmp_var()
    stored = tmp_var()
    flag(:rathena)
    {writeback, :cont} = emit_assign(target, {:temp, stored}, env)

    lines =
      [
        "{ctx, #{raw}} = input(ctx, #{kind})",
        "{#{status}, #{stored}} = Rathena.#{helper}(#{raw}, #{min}, #{max})"
      ] ++ writeback

    {status, lines}
  end

  # rAthena `input` bounds default to `[0, INT_MAX]`.
  defp input_bounds([], _env), do: {"0", "2_147_483_647"}
  defp input_bounds([min], env), do: {render(min, env), "2_147_483_647"}
  defp input_bounds([min, max | _], env), do: {render(min, env), render(max, env)}

  defp hoist_list(exprs, env, pre) do
    Enum.reduce(exprs, {[], pre}, fn expr, {acc, pre} ->
      {expr, pre} = hoist_walk(expr, env, pre)
      {acc ++ [expr], pre}
    end)
  end

  defp hoist_postfix(target, op, env, pre) do
    tmp = tmp_var()
    read = read_var(target, pad_default(target), env)
    set = set_var(target, "#{tmp} #{op} 1", env)
    {{:temp, tmp}, [set, "#{tmp} = #{read}" | pre]}
  end

  # -- expression rendering ----------------------------------------------------

  defp render({:temp, name}, _env), do: name
  defp render({:int, n}, _env), do: to_string(n)
  defp render({:str, s}, _env), do: inspect(s)
  defp render({:neg, e}, env), do: "-(#{render(e, env)})"
  defp render({:bnot, e}, env), do: ":erlang.bnot(#{render(e, env)})"

  defp render({:var, _, _, _} = var, _env), do: read_var(var, var_default(var), nil)

  defp render({:name, name}, env) do
    with :error <- read_name(name),
         :error <- Resolver.constant(name) do
      read_var({:name, name}, name_default(name), env)
    else
      {:ok, rendered} -> rendered
    end
  end

  defp render({:index, base, index}, env),
    do: "Enum.at(#{read_var(base, "[]", env)}, #{render(index, env)}, #{pad_default(base)})"

  defp render({:ternary, c, t, f}, env),
    do: "(if #{cond_str(c, env)}, do: #{render(t, env)}, else: #{render(f, env)})"

  defp render({:not, _} = e, env), do: bool_value(e, env)

  defp render({:bin, op, _, _} = e, env) when is_map_key(@comparisons, op),
    do: bool_value(e, env)

  defp render({:bin, op, _, _} = e, env) when op in [:&&, :||], do: bool_value(e, env)

  defp render({:bin, :+, l, r} = e, env) do
    if stringy?(e) do
      flag(:rathena)
      "Rathena.concat(#{render(l, env)}, #{render(r, env)})"
    else
      "(#{render(l, env)} + #{render(r, env)})"
    end
  end

  defp render({:bin, op, l, r}, env) when is_map_key(@arith, op),
    do: "(#{render(l, env)} #{@arith[op]} #{render(r, env)})"

  defp render({:bin, :/, l, r}, env), do: "div(#{render(l, env)}, #{render(r, env)})"
  defp render({:bin, :%, l, r}, env), do: "rem(#{render(l, env)}, #{render(r, env)})"

  defp render({:bin, op, l, r}, env) when is_map_key(@bitwise, op),
    do: ":erlang.#{@bitwise[op]}(#{render(l, env)}, #{render(r, env)})"

  defp render({:call, "getarg", [index]}, %{sub: true} = env),
    do: "Enum.at(args, #{render(index, env)}, 0)"

  defp render({:call, "getarg", [index, default]}, %{sub: true} = env),
    do: "Enum.at(args, #{render(index, env)}, #{render(default, env)})"

  defp render({:call, "getarg", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:getarg, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  defp render({:call, "getargcount", []}, %{sub: true}), do: "length(args)"

  defp render({:call, "getargcount", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:getargcount, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  defp render({:call, "sprintf", [template | args]}, env) do
    flag(:rathena)
    rendered_args = Enum.map_join(args, ", ", &render(&1, env))
    "Rathena.format(#{render(template, env)}, [#{rendered_args}])"
  end

  defp render({:call, "getitemname", [item]}, env) do
    flag(:rathena)
    "Rathena.getitemname(#{typed_arg(item, :item, env)})"
  end

  defp render({:call, name, args}, env) when is_map_key(@rathena_calls, name) do
    if length(args) in Map.fetch!(@rathena_calls, name) do
      flag(:rathena)
      "Rathena.#{name}(#{Enum.map_join(args, ", ", &render(&1, env))})"
    else
      flag(:todo_mod)
      "Todo.call!(#{atom_lit(name)}, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
    end
  end

  defp render({:call, "rand", [max]}, env),
    do: ":rand.uniform(#{render(max, env)}) - 1"

  defp render({:call, "rand", [lo, hi]}, env),
    do: "Enum.random(#{render(lo, env)}..#{render(hi, env)})"

  # `getarraysize(getd("…"))` sizes the runtime-named array.
  defp render({:call, "getarraysize", [{:call, "getd", [name]}]}, env),
    do: "length(getd(ctx, #{render(name, env)}))"

  defp render({:call, "getarraysize", [array]}, env),
    do: "length(#{read_var(array, "[]", env)})"

  # `getd("<name>")` reads a variable whose full name is built at runtime;
  # any other arity stays a stub.
  defp render({:call, "getd", args}, env) do
    case args do
      [name] -> "getd(ctx, #{render(name, env)})"
      _ -> unsupported_call("getd", args, env)
    end
  end

  # `getvariableofnpc(<.var>, "<npc>")` reads another NPC's `.` variable by
  # name; an indexed ref reads an array element. Any other ref shape (a dynamic
  # `getd` name or a non-npc scope) stays a stub.
  defp render({:call, "getvariableofnpc", [var_ref, npc_name]}, env) do
    case npc_var_of_read(var_ref, render_str(npc_name, env), env) do
      {:ok, expr} -> expr
      :error -> unsupported_call("getvariableofnpc", [var_ref, npc_name], env)
    end
  end

  # rAthena atoi: C-style leading-integer parse, 0 when there are no digits.
  defp render({:call, "atoi", [value]}, env) do
    flag(:rathena)
    "Rathena.atoi(#{render(value, env)})"
  end

  # rAthena implode(<array>{,<glue>}): joins a string array, with no
  # separator when the glue is omitted.
  defp render({:call, "implode", [array]}, env),
    do: "Enum.join(#{read_var(array, "[]", env)})"

  defp render({:call, "implode", [array, glue]}, env),
    do: "Enum.join(#{read_var(array, "[]", env)}, #{render_str(glue, env)})"

  # rAthena getnpctimer(type{,"name"}): only TYPE 0 (elapsed ms) is supported;
  # types 1 (started?) and 2 (tick amount) have no DSL equivalent yet.
  defp render({:call, "getnpctimer", [{:int, 0}]}, _env), do: "getnpctimer(ctx)"

  defp render({:call, "getnpctimer", [{:int, 0}, {:str, name}]}, _env),
    do: "getnpctimer(ctx, #{inspect(name)})"

  defp render({:call, "getnpctimer", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:getnpctimer, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  # rAthena getnpcid(type{,"name"}): only TYPE 0 (the NPC's own unit id, or a
  # named NPC's) is supported; other types have no DSL equivalent yet.
  defp render({:call, "getnpcid", [{:int, 0}]}, _env), do: "getnpcid(ctx)"

  defp render({:call, "getnpcid", [{:int, 0}, name]}, env),
    do: "getnpcid(ctx, #{render_str(name, env)})"

  defp render({:call, "getnpcid", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:getnpcid, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  defp render({:call, "playerattached", []}, _env), do: "playerattached(ctx)"

  defp render({:call, "playerattached", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:playerattached, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  # rAthena strnpcinfo(type{,"name"}): the self form maps to strnpcinfo(ctx,
  # type); the named-NPC form has no DSL equivalent yet.
  defp render({:call, "strnpcinfo", [type]}, env),
    do: "strnpcinfo(ctx, #{typed_arg(type, :int, env)})"

  defp render({:call, "strnpcinfo", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:strnpcinfo, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  # rAthena checkweight(id,amt{,id,amt...}): consecutive item-id/amount pairs
  # become a list of `{id, amount}` tuples. checkweight2 (paired arrays) is a
  # different shape and stays a stub.
  defp render({:call, "checkweight", args}, env)
       when args != [] and rem(length(args), 2) == 0 do
    pairs =
      args
      |> Enum.chunk_every(2)
      |> Enum.map_join(", ", fn [id, amt] ->
        "{#{typed_arg(id, :item, env)}, #{typed_arg(amt, :int, env)}}"
      end)

    "checkweight(ctx, [#{pairs}])"
  end

  defp render({:call, "checkweight", args}, env) do
    flag(:todo_mod)
    "Todo.call!(:checkweight, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  # rAthena isequippedcnt(eq1, eq2, ...): a variable list of item/card ids
  # collected into the DSL's list argument.
  defp render({:call, "isequippedcnt", args}, env) when args != [] do
    ids = Enum.map_join(args, ", ", &typed_arg(&1, :item, env))
    "isequippedcnt(ctx, [#{ids}])"
  end

  defp render({:call, "isequippedcnt", _args}, _env), do: "isequippedcnt(ctx, [])"

  defp render({:call, name, args}, env) do
    case CommandMap.call_read(name) do
      {:ok, %{shape: :nullary, dsl: dsl}} when args == [] ->
        "#{dsl}(ctx)"

      {:ok, %{shape: :nullary}} ->
        flag(:todo_mod)
        "Todo.call!(#{atom_lit(name)}, [#{Enum.map_join(args, ", ", &render(&1, env))}])"

      {:ok, %{shape: :opt_read, dsl: dsl}} ->
        opt_read_call(dsl, name, args, env)

      {:ok, %{shape: :quest_check, dsl: dsl}} ->
        quest_check_call(dsl, name, args, env)

      {:ok, %{shape: :item_group_optional, dsl: dsl, args: types}} ->
        item_group_optional_call(dsl, name, args, types, env)

      {:ok, %{dsl: dsl, args: types}} ->
        rendered =
          args
          |> Enum.zip(types ++ List.duplicate(:int, max(length(args) - length(types), 0)))
          |> Enum.map(fn {arg, type} -> typed_arg(arg, type, env) end)

        "#{dsl}(#{Enum.join(["ctx" | rendered], ", ")})"

      :error ->
        render_global_read(name, args, env)
    end
  end

  # Anything the renderer has no shape for becomes a raising stub, keeping
  # one exotic expression from failing the whole entry.
  defp render(other, _env) do
    flag(:todo_mod)
    "Todo.call!(:expr, [#{inspect(inspect(other))}])"
  end

  # `getvariableofnpc(.var, "<npc>")` read/write helpers. Defined outside the
  # `render/2` clause group so that group stays contiguous.
  defp npc_var_of_read({:var, :npc, name, type}, npc_name, _env) do
    default = pad_default({:var, :npc, name, type})
    {:ok, "get_npc_var_of(ctx, #{scope_var_key(name, type)}, #{npc_name}, #{default})"}
  end

  defp npc_var_of_read({:index, {:var, :npc, name, type}, index}, npc_name, env) do
    default = pad_default({:var, :npc, name, type})

    {:ok,
     "Enum.at(get_npc_var_of(ctx, #{scope_var_key(name, type)}, #{npc_name}, []), " <>
       "#{render(index, env)}, #{default})"}
  end

  defp npc_var_of_read(_ref, _npc_name, _env), do: :error

  defp npc_var_of_key({:var, :npc, name, type}), do: {:ok, scope_var_key(name, type)}
  defp npc_var_of_key(_ref), do: :error

  defp item_group_optional_args(args, types, env) do
    case length(args) - length(types) do
      0 -> {:ok, Enum.zip_with(args, types, &typed_arg(&1, &2, env)) ++ ["0"]}
      1 -> {:ok, Enum.zip_with(args, types ++ [:int], &typed_arg(&1, &2, env))}
      _other -> :error
    end
  end

  # `getrandgroupitem`/`groupranditem`: render the item-group read/command,
  # appending the default subgroup `0` when omitted; any other arity stays a
  # stub.
  defp item_group_optional_call(dsl, name, args, types, env) do
    case item_group_optional_args(args, types, env) do
      {:ok, rendered} -> "#{dsl}(#{Enum.join(["ctx" | rendered], ", ")})"
      :error -> unsupported_call(name, args, env)
    end
  end

  defp unsupported_call(name, args, env) do
    flag(:todo_mod)
    "Todo.call!(#{atom_lit(name)}, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  # A global rAthena function (`F_GetNumSuffix`, `F_CanChangeJob`) invoked with
  # the direct-call syntax `Name(args)` rather than `callfunc "Name", args`.
  # `:read` globals render inline like their callfunc form; anything else stubs.
  defp render_global_read(name, args, env) do
    case CommandMap.function(name) do
      {:ok, %{kind: :read, dsl: dsl}} ->
        read_fn_call(dsl, args, Enum.map_join(args, ", ", &render(&1, env)))

      _ ->
        flag(:todo_mod)
        "Todo.call!(#{atom_lit(name)}, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
    end
  end

  # `checkquest`/`questprogress`: 1-arg form defaults the DSL's own
  # `:havequest` mode; the 2-arg form resolves the mode constant. Any other
  # arity is a form the buildin doesn't have, so it stays a stub.
  defp quest_check_call(dsl, _name, [id], env),
    do: "#{dsl}(ctx, #{typed_arg(id, :int, env)})"

  defp quest_check_call(dsl, _name, [id, mode], env),
    do: "#{dsl}(ctx, #{typed_arg(id, :int, env)}, #{typed_arg(mode, :quest_mode, env)})"

  defp quest_check_call(_dsl, name, args, env) do
    flag(:todo_mod)
    "Todo.call!(#{atom_lit(name)}, [#{Enum.map_join(args, ", ", &render(&1, env))}])"
  end

  # `is_party_leader({<party id>})`: the zero-arg form reads the attached
  # player's own party; the one-arg form targets a specific party id. Any longer
  # form is a form the buildin doesn't have, so it stays a stub.
  defp opt_read_call(dsl, _name, [], _env), do: "#{dsl}(ctx)"

  defp opt_read_call(dsl, _name, [arg], env),
    do: "#{dsl}(ctx, #{typed_arg(arg, :int, env)})"

  defp opt_read_call(_dsl, name, args, env), do: unsupported_call(name, args, env)

  defp read_name(name) do
    case CommandMap.read(name) do
      {:ok, fun} -> {:ok, "#{fun}(ctx)"}
      :error -> :error
    end
  end

  defp var_default({:var, _, _, :str}), do: ~s("")
  defp var_default(_), do: "0"

  defp name_default(name), do: if(String.ends_with?(name, "$"), do: ~s(""), else: "0")

  defp bool_value(e, env) do
    flag(:rathena)
    "Rathena.bool_int(#{cond_str(e, env)})"
  end

  # Renders an expression in boolean (condition) position.
  defp cond_str({:bin, op, l, r}, env) when is_map_key(@comparisons, op),
    do: "#{render(l, env)} #{@comparisons[op]} #{render(r, env)}"

  defp cond_str({:bin, :&&, l, r}, env), do: "(#{cond_str(l, env)}) and (#{cond_str(r, env)})"
  defp cond_str({:bin, :||, l, r}, env), do: "(#{cond_str(l, env)}) or (#{cond_str(r, env)})"
  defp cond_str({:not, e}, env), do: "not (#{cond_str(e, env)})"
  defp cond_str({:int, 0}, _env), do: "false"
  defp cond_str({:int, _}, _env), do: "true"

  defp cond_str(e, env) do
    flag(:rathena)
    "Rathena.truthy?(#{render(e, env)})"
  end

  # A string-typed subtree turns `+` into concatenation.
  defp stringy?({:str, _}), do: true
  defp stringy?({:var, _, _, :str}), do: true
  defp stringy?({:name, name}), do: String.ends_with?(name, "$")
  defp stringy?({:bin, :+, l, r}), do: stringy?(l) or stringy?(r)
  defp stringy?({:index, base, _}), do: stringy?(base)
  defp stringy?({:ternary, _, t, f}), do: stringy?(t) or stringy?(f)
  defp stringy?(_), do: false

  defp render_str(e, env) do
    cond do
      stringy?(e) or match?({:temp, _}, e) -> render(e, env)
      match?({:int, _}, e) -> inspect(to_string(elem(e, 1)))
      true -> "to_string(#{render(e, env)})"
    end
  end

  defp concat_all([single]), do: single

  defp concat_all(parts) do
    flag(:rathena)
    Enum.reduce(parts, fn part, acc -> "Rathena.concat(#{acc}, #{part})" end)
  end

  # rAthena select options: each literal argument may itself be a
  # `"a:b:c"`-separated list; dynamic arguments split at runtime.
  defp options(args, env) do
    if Enum.all?(args, &match?({:str, _}, &1)) do
      args
      |> Enum.flat_map(fn {:str, s} -> String.split(s, ":") end)
      |> inspect()
    else
      case args do
        [single] ->
          "String.split(#{render_str(single, env)}, \":\")"

        many ->
          rendered = Enum.map_join(many, ", ", &render_str(&1, env))
          "Enum.flat_map([#{rendered}], &String.split(&1, \":\"))"
      end
    end
  end

  defp branch_body(lines, :cont), do: lines ++ ["ctx"]
  defp branch_body(lines, _terminal), do: lines

  defp merge_terminal(:stop, :stop), do: :stop
  defp merge_terminal(_, _), do: :cont

  # A subroutine/function body that early-returns from below its top level
  # (see `emit_stmt({:return, ...}, %{catch_return: true})`) is wrapped so the
  # `throw` lands on the catch and produces the function's `{ctx, value}`.
  defp wrap_return_catch(body, false), do: body

  defp wrap_return_catch(body, true) do
    """
    try do
    #{body}
    catch
    :throw, {:script_return, result} -> result
    end
    """
  end

  # Does this statement list contain a `return` nested inside a control-flow
  # construct (so a continuing sibling path can follow it)? Such a return can't
  # be a plain tail `{ctx, value}` and must throw to a wrapping catch. A bare
  # top-level `return` stays a tail expression, so it is not counted here.
  defp needs_return_catch?(stmts), do: Enum.any?(stmts, &nested_return?/1)

  defp nested_return?({:if, _, then_stmts, else_stmts}),
    do: any_return?(then_stmts) or any_return?(else_stmts)

  defp nested_return?({:switch, _, clauses}),
    do: Enum.any?(clauses, fn {_values, stmts} -> any_return?(stmts) end)

  defp nested_return?({:while, _, body}), do: any_return?(body)
  defp nested_return?({:do_while, body, _}), do: any_return?(body)
  defp nested_return?({:for, _, _, _, body}), do: any_return?(body)
  defp nested_return?({:block, stmts}), do: any_return?(stmts)
  defp nested_return?(_), do: false

  defp any_return?(stmts) do
    Enum.any?(stmts, fn
      {:return, _} -> true
      other -> nested_return?(other)
    end)
  end

  defp local_fn_name(name), do: "fn_" <> ModuleName.slug(name)

  # -- emitter state (process dictionary; reset per generate/2) ----------------

  defp reset_state do
    Process.put(:codegen_tmp, 0)
    Process.put(:codegen_id, 0)
    Process.put(:codegen_defs, [])
    Process.put(:codegen_flags, MapSet.new())
  end

  defp tmp_var do
    n = Process.get(:codegen_tmp) + 1
    Process.put(:codegen_tmp, n)
    "v#{n}"
  end

  defp next_id do
    n = Process.get(:codegen_id) + 1
    Process.put(:codegen_id, n)
    n
  end

  defp defer(def_string) do
    Process.put(:codegen_defs, Process.get(:codegen_defs) ++ [def_string])
    :ok
  end

  defp get_defs, do: Process.get(:codegen_defs)

  defp flag(name) do
    Process.put(:codegen_flags, MapSet.put(Process.get(:codegen_flags), name))
    :ok
  end

  defp flag?(name), do: MapSet.member?(Process.get(:codegen_flags), name)
end
