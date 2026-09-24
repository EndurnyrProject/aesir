# Differential harness for behavior-preserving NPC refactors.
#
# Usage (plain elixir, no Mix, no compiled project needed):
#
#     git show HEAD:<path/to/npc.ex> > /tmp/old_npc.ex
#     elixir .agents/skills/aesir-npc/scripts/npc_diff_harness.exs /tmp/old_npc.ex <path/to/npc.ex> [scenarios]
#
# Loads both versions of an NPC module against a fake, recording DSL and runs
# `on_talk/1` plus every literal `on_event/2` label under `scenarios` (default 3000)
# deterministic seeds per entry point. Each seed fixes every read (char vars,
# job, level, items, menu choices, inputs, random rolls), so both versions see
# the same world; the ordered effect logs must be identical.
#
# Output, one line per file:
#
#     npc.ex: entries=N distinct_paths=P mismatches=M error_outcomes=[...]
#
# - mismatches > 0: the first three diverging runs are printed with both logs.
# - error_outcomes: entry points where BOTH versions raised. Usually a harness gap
#   (an unmodelled read returning the wrong shape) that hides the paths behind it.
#   Rerun with NPC_HARNESS_DEBUG=1 to print the exception messages, then add a
#   `call/2` clause to `H.Core` for the missing read.
# - distinct_paths: a quest NPC stuck at 1-2 paths means a gate is never passed;
#   check which read guards it.
#
# How the model works:
#
# - Every local, non-Kernel call in the module body is redirected to `H.Core.call/2`.
#   Unknown ctx-first calls are logged as effects and return the ctx; reads need an
#   explicit clause. `Helper.call(ctx, args)` maps to the downcased last alias segment
#   (for example `FClearjobvar.call` -> `:fclearjobvar`).
# - `Rathena.*` helpers go through `H.Core.rathena/2`.
# - `Enum.random/1` and `:rand.uniform/1` share one draw counter, so swapping one for
#   the other stays comparable when the ranges are equivalent.
# - Integer and atom literals from both files seed the read domains, so gates such as
#   `QUEST_Q == 16` or `base_job == :merchant` are reachable.
# - `Ctx` is a top-level struct with `status: :ok`, so `%Ctx{status: {:error, _}}`
#   halted-ctx guards in refactored code match as they do at runtime.
#
# This is a model, not the runtime: a clean result is strong evidence, not proof.
# It is a refactoring aid only; do not add it to the test suite.

[old_path, new_path | rest] = System.argv()

scenarios =
  case rest do
    [x | _] -> String.to_integer(x)
    [] -> 3000
  end

defmodule Ctx do
  defstruct log: [], charvars: %{}, locals: %{}, npcvars: %{}, status: :ok
end

defmodule H.Core do
  @moduledoc false

  @int_domain [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 20, 40, 99, -1]
  @jobs [:archer, :archer, :archer, :archer, :bard, :dancer, :novice, :clown, :gypsy]
  @base_classes [:novice, :swordman, :mage, :archer, :acolyte, :merchant, :thief, :taekwon]

  def seed, do: Process.get(:seed)
  def ints, do: :persistent_term.get(:h_ints)
  def atoms, do: :persistent_term.get(:h_atoms)

  def pick(key, domain), do: Enum.at(domain, rem(:erlang.phash2({seed(), key}), length(domain)))

  def counter(k) do
    c = Process.get({:counter, k}, 0)
    Process.put({:counter, k}, c + 1)
    c
  end

  def log(ctx, entry), do: %{ctx | log: [entry | ctx.log]}

  def random(range), do: pick({:random, counter(:random)}, Enum.to_list(range))

  def call(:get_char_var, [ctx, key, default]) do
    case Map.fetch(ctx.charvars, key) do
      {:ok, v} -> v
      :error -> pick({:gcv, key}, [default | ints()])
    end
  end

  def call(:get_char_var, [ctx, key]), do: call(:get_char_var, [ctx, key, 0])

  def call(:set_char_var, [ctx, key, value]) do
    ctx |> log({:set_char_var, key, value}) |> Map.update!(:charvars, &Map.put(&1, key, value))
  end

  def call(:get_npc_var, [ctx, key, default]) do
    case Map.fetch(ctx.npcvars, key) do
      {:ok, v} -> v
      :error -> pick({:gnv, key}, [default | ints()])
    end
  end

  def call(:set_npc_var, [ctx, key, value]) do
    ctx |> log({:set_npc_var, key, value}) |> Map.update!(:npcvars, &Map.put(&1, key, value))
  end

  def call(:get_npc_var_of, [_ctx, npc, key, default]),
    do: pick({:gnvo, npc, key}, [default | @int_domain])

  def call(:get_server_temp_var, [_ctx, key, default]),
    do: pick({:gstv, key}, [default, [], [1, 2], [150_001, 150_002, 150_003]])

  def call(:get_local, [ctx, key, default]), do: Map.get(ctx.locals, key, default)
  def call(:set_local, [ctx, key, value]), do: %{ctx | locals: Map.put(ctx.locals, key, value)}
  def call(:set_local, [ctx, key]), do: %{ctx | locals: Map.put(ctx.locals, key, 0)}

  def call(:select, [ctx, options]) do
    choice = pick({:select, counter(:select)}, Enum.to_list(1..length(options)) ++ [255])
    {log(ctx, {:select, options, choice}), choice}
  end

  def call(:input, [ctx | kind]) do
    guess =
      Enum.find_value(ctx.log, "", fn
        {:mes, [text]} when is_binary(text) ->
          if String.ends_with?(text, "^000000"),
            do: String.replace(text, ~r/\^[0-9A-Fa-f]{6}/, "")

        _ ->
          nil
      end)

    domain = List.duplicate(guess, 7) ++ ["wrong", 0, nil]
    v = pick({:input, counter(:input)}, domain)
    {log(ctx, {:input, kind, v}), v}
  end

  def call(:attachrid, [ctx | args]) do
    ok = pick({:attachrid, args, counter(:attachrid)}, [0, 1])
    {log(ctx, {:attachrid, args, ok}), ok}
  end

  def call(:upper, [_ctx]), do: pick(:upper, [0, 1, 2])
  def call(:sex, [_ctx]), do: pick(:sex, [0, 1])
  def call(name, [_ctx]) when name in [:base_job, :class], do: pick(name, @jobs ++ atoms())
  def call(:base_class, [_ctx]), do: pick(:base_class, atoms() ++ @base_classes)
  def call(:job_level, [_ctx]), do: pick(:job_level, [10, 39, 40, 41, 50] ++ ints())
  def call(:base_level, [_ctx]), do: pick(:base_level, [10, 39, 40, 41, 50, 99])
  def call(:skill_point, [_ctx]), do: pick(:skill_point, [0, 0, 0, 1])
  def call(:zeny, [_ctx]), do: pick(:zeny, [0, 9999, 10_000, 50_000])
  def call(:weight, [_ctx]), do: pick(:weight, [0, 100, 5000, 20_000])
  def call(:char_name, [_ctx | args]), do: "Name#{inspect(args)}"

  def call(:count_item, [_ctx | args]),
    do: pick({:count_item, args}, [0, 1, 2, 3, 5, 10, 20, 60, 100])

  def call(:checkquest, [_ctx | args]), do: pick({:checkquest, args}, [-1, 0, 1, 2])
  def call(:getskilllv, [_ctx | args]), do: pick({:getskilllv, args}, [0, 1, 5, 10])
  def call(:mobcount, [_ctx | args]), do: pick({:mobcount, args}, [0, 1, 2, 5])
  def call(:getmapusers, [_ctx | args]), do: pick({:getmapusers, args}, [0, 1, 2, 5])
  def call(:getcharid, [_ctx | args]), do: pick({:getcharid, args}, [0, 150_001, 150_002])
  def call(:checkweight, [_ctx | args]), do: pick({:checkweight, args}, [true, false])
  def call(:can_change_job?, [_ctx | args]), do: pick({:ccj, args}, [true, false])

  def call(name, [_ctx]) when name in [:checkcart, :checkfalcon, :checkriding],
    do: pick(name, [true, false])

  def call(:finsertplural, [ctx | args]),
    do: {log(ctx, {:finsertplural, args}), "plural#{inspect(args)}"}

  def call(:fclearjobvar, [ctx | args]), do: {log(ctx, {:fclearjobvar, args}), nil}

  def call(name, [%Ctx{} = ctx | args]), do: log(ctx, {name, args})
  def call(name, args), do: raise("unhandled #{name}/#{length(args)} #{inspect(args)}")

  def rathena(:concat, [a, b]), do: to_string(a) <> to_string(b)
  def rathena(:job_id, [id]) when is_integer(id), do: id
  def rathena(:job_id, [id]) when is_atom(id), do: :erlang.phash2(id)
  def rathena(:truthy?, [x]), do: x not in [0, "", false, nil]
  def rathena(:getitemname, [id]), do: "Item#{id}"
  def rathena(:bool_int, [b]), do: if(b, do: 1, else: 0)
  def rathena(f, args), do: raise("unhandled Rathena.#{f} #{inspect(args)}")

  def rathena(piped, f, args), do: rathena(f, [piped | args])
end

defmodule H.Load do
  @moduledoc false

  @kernel Kernel.SpecialForms.__info__(:macros) ++
            Kernel.__info__(:macros) ++ Kernel.__info__(:functions)
  @kernel_names Enum.map(@kernel, &elem(&1, 0))
  @syntax [:__block__, :__aliases__, :fn, :->, :when, :<-, :"::", :{}, :%{}, :%, :^, :&, :.]

  def load(path, as) do
    {:ok, {:defmodule, meta, [_name, [do: body]]}} = Code.string_to_quoted(File.read!(path))
    body = strip(body)
    defined = defined(body) ++ attributes(body)

    body =
      Macro.prewalk(body, fn
        {{:., _, [{:__aliases__, _, [:Rathena]}, f]}, _, args} ->
          quote do: H.Core.rathena(unquote(f), unquote(args))

        {{:., _, [{:__aliases__, _, [:Enum]}, :random]}, _, args} ->
          quote do: H.Core.random(unquote_splicing(args))

        {{:., _, [:rand, :uniform]}, _, [n]} ->
          quote do: H.Core.random(1..unquote(n))

        {{:., m2, [{:__aliases__, _, mods}, :call]}, m3, args} when mods != [:Enum] ->
          {{:., m2, [{:__aliases__, [], [:H]}, helper_name(mods)]}, m3, args}

        {name, meta, args} = node when is_atom(name) and is_list(args) ->
          if redirect?(name, defined),
            do: {{:., meta, [{:__aliases__, [], [:H]}, name]}, meta, args},
            else: node

        node ->
          node
      end)

    Code.eval_quoted({:defmodule, meta, [{:__aliases__, [], [as]}, [do: body]]})
  end

  def helper_name(mods),
    do: mods |> List.last() |> Atom.to_string() |> String.downcase() |> String.to_atom()

  defp redirect?(name, defined) do
    name not in defined and name not in @syntax and name not in @kernel_names and
      Atom.to_string(name) =~ ~r/^[a-z][a-zA-Z0-9_]*[?!]?$/
  end

  defp attributes(body) do
    {_, attrs} =
      Macro.prewalk(body, [], fn
        {:@, _, [{a, _, _}]} = node, acc -> {node, [a | acc]}
        node, acc -> {node, acc}
      end)

    attrs
  end

  defp strip({:__block__, m, exprs}), do: {:__block__, m, Enum.reject(exprs, &drop?/1)}
  defp strip(e), do: if(drop?(e), do: {:__block__, [], []}, else: e)

  defp drop?({:use, _, _}), do: true
  defp drop?({:alias, _, _}), do: true
  defp drop?({:@, _, [{a, _, _}]}) when a in [:impl, :spec, :moduledoc, :doc], do: true
  defp drop?(_), do: false

  defp defined({:__block__, _, exprs}), do: Enum.flat_map(exprs, &def_name/1)
  defp defined(e), do: def_name(e)

  defp def_name({d, _, [{:when, _, [{name, _, _} | _]} | _]}) when d in [:def, :defp], do: [name]
  defp def_name({d, _, [{name, _, _} | _]}) when d in [:def, :defp], do: [name]
  defp def_name(_), do: []
end

defmodule H.Gen do
  @moduledoc false

  @reserved [:def, :defp, :defmodule, :if, :case, :cond, :try, :fn, :when, :and, :or, :not] ++
              [:in, :do, :use, :alias, :import, :quote, :unquote, :for, :with, :receive] ++
              [:throw, :raise]

  def gen(paths) do
    names =
      for path <- paths, reduce: MapSet.new() do
        acc ->
          {:ok, ast} = Code.string_to_quoted(File.read!(path))

          {_, acc} =
            Macro.prewalk(ast, acc, fn
              {{:., _, [{:__aliases__, _, mods}, :call]}, _, _} = node, acc ->
                {node, MapSet.put(acc, H.Load.helper_name(mods))}

              {n, _, a} = node, acc when is_atom(n) and is_list(a) ->
                {node, MapSet.put(acc, n)}

              node, acc ->
                {node, acc}
            end)

          acc
      end

    defs =
      for name <- names,
          Atom.to_string(name) =~ ~r/^[a-z][a-zA-Z0-9_]*[?!]?$/,
          name not in @reserved,
          arity <- 0..10 do
        args = Macro.generate_arguments(arity, nil)

        quote do
          def unquote(name)(unquote_splicing(args)),
            do: H.Core.call(unquote(name), unquote(args))
        end
      end

    Code.eval_quoted(
      quote do
        defmodule H do
          (unquote_splicing(defs))
        end
      end
    )
  end
end

Code.compiler_options(ignore_module_conflict: true)

{ints, atoms} =
  for path <- [old_path, new_path],
      reduce: {MapSet.new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99, -1]), MapSet.new()} do
    acc ->
      {:ok, ast} = Code.string_to_quoted(File.read!(path))

      {_, acc} =
        Macro.prewalk(ast, acc, fn
          i, {is, as} when is_integer(i) and i >= -1 and i < 100_000 ->
            {i, {is |> MapSet.put(i - 1) |> MapSet.put(i) |> MapSet.put(i + 1), as}}

          a, {is, as} when is_atom(a) and a not in [nil, true, false] ->
            {a, {is, MapSet.put(as, a)}}

          node, acc ->
            {node, acc}
        end)

      acc
  end

:persistent_term.put(:h_ints, Enum.sort(ints))

:persistent_term.put(
  :h_atoms,
  atoms |> Enum.filter(&(Atom.to_string(&1) =~ ~r/^[a-z][a-z_0-9]*$/)) |> Enum.sort()
)

H.Gen.gen([old_path, new_path])
H.Load.load(old_path, OldMod)
H.Load.load(new_path, NewMod)

labels = fn path ->
  {:ok, ast} = Code.string_to_quoted(File.read!(path))

  {_, acc} =
    Macro.prewalk(ast, [], fn
      {:def, _, [{:on_event, _, [l, _]} | _]} = node, acc when is_binary(l) -> {node, [l | acc]}
      node, acc -> {node, acc}
    end)

  Enum.reverse(acc)
end

old_labels = labels.(old_path)
new_labels = labels.(new_path)

if old_labels != new_labels,
  do: IO.puts("LABEL MISMATCH #{inspect(old_labels)} vs #{inspect(new_labels)}")

debug? = System.get_env("NPC_HARNESS_DEBUG") in ["1", "true"]

run = fn mod, entry, seed ->
  Enum.each(Process.get_keys(), fn k -> if match?({:counter, _}, k), do: Process.delete(k) end)
  Process.put(:seed, seed)
  ctx = struct(Ctx, [])

  try do
    result =
      case entry do
        :talk -> mod.on_talk(ctx)
        {:event, label} -> mod.on_event(label, ctx)
      end

    {:ok, Enum.reverse(result.log)}
  rescue
    e ->
      if debug?, do: IO.puts("#{inspect(mod)} #{inspect(entry)}: #{Exception.message(e)}")
      {:error, e.__struct__}
  catch
    kind, value -> {:caught, kind, value}
  end
end

entries =
  if function_exported?(OldMod, :on_talk, 1),
    do: [:talk | Enum.map(old_labels, &{:event, &1})],
    else: Enum.map(old_labels, &{:event, &1})

{mismatches, paths} =
  for entry <- entries, seed <- 1..scenarios, reduce: {0, MapSet.new()} do
    {bad, paths} ->
      old = run.(OldMod, entry, seed)
      new = run.(NewMod, entry, seed)
      paths = MapSet.put(paths, {entry, old})

      if old == new do
        {bad, paths}
      else
        if bad < 3 do
          IO.puts("MISMATCH #{inspect(entry)} seed=#{seed}")
          IO.inspect(old, label: "old", limit: :infinity)
          IO.inspect(new, label: "new", limit: :infinity)
        end

        {bad + 1, paths}
      end
  end

errors = paths |> Enum.reject(&match?({_, {:ok, _}}, &1)) |> Enum.uniq()

IO.puts(
  "#{Path.basename(new_path)}: entries=#{length(entries)} distinct_paths=#{MapSet.size(paths)} " <>
    "mismatches=#{mismatches} error_outcomes=#{inspect(errors)}"
)
