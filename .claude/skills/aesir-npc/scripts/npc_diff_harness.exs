# Differential harness for behavior-preserving NPC refactors.
#
# Usage (plain elixir, no Mix, no compiled project needed):
#
#     git show HEAD:<path/to/npc.ex> > /tmp/old_npc.ex
#     elixir .agents/skills/aesir-npc/scripts/npc_diff_harness.exs /tmp/old_npc.ex <path/to/npc.ex> [scenarios]
#
# Loads both versions of an NPC module against a fake, recording DSL and runs
# `on_talk/1` plus every literal `on_event/2` label under `scenarios` (default 3000)
# deterministic seeds per entry point. A global helper module (one exporting
# `call/2` and no `on_talk/1`) is driven through `call/2` instead, with seeded
# argument lists. Each seed fixes every read (char vars,
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
#   Rerun with NPC_HARNESS_DEBUG=1 to print the exception message and stack trace,
#   then add a `call/2` clause to `H.Core` for the missing read. Adding
#   NPC_HARNESS_STRICT=1 as well makes the first unmodelled ctx-first call raise and
#   print its name (effects such as `mes` show up too, so read past them).
# - distinct_paths: a quest NPC stuck at 1-2 paths means a gate is never passed;
#   check which read guards it. Class-quest NPCs are commonly gated on `checkre`,
#   `eaclass` or `gettime`, which are modelled below.
#
# How the model works:
#
# - Every local, non-Kernel call in the module body is redirected to `H.Core.call/2`.
#   Unknown ctx-first calls are logged as effects and return the ctx; reads need an
#   explicit clause. `Helper.call(ctx, args)` maps to the downcased last alias segment
#   (for example `FClearjobvar.call` -> `:fclearjobvar`).
# - `Rathena.*` helpers go through `H.Core.rathena/2`. The ones with a project-specific
#   model (item names, job ids, array writes) are defined there; any other helper is
#   delegated to the real `Aesir.ZoneServer.Script.Rathena`, compiled from source.
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
  defstruct log: [], charvars: %{}, locals: %{}, npcvars: %{}, tempvars: %{}, status: :ok
end

# The project's string/array helpers (Rathena) are deterministic and have no I/O, so the
# unmodelled ones are delegated to the real module instead of being reimplemented here.
rathena_source =
  Path.expand("../../../../apps/zone_server/lib/aesir/zone_server/script/rathena.ex", __DIR__)

if File.exists?(rathena_source) do
  # Its callers reference modules this script does not load; only warnings result.
  Code.compiler_options(no_warn_undefined: :all)
  Code.compile_file(rathena_source)
end

defmodule H.Core do
  @moduledoc false

  @int_domain [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 20, 40, 99, -1]
  @jobs [:archer, :archer, :archer, :archer, :bard, :dancer, :novice, :clown, :gypsy]
  @base_classes [:novice, :swordman, :mage, :archer, :acolyte, :merchant, :thief, :taekwon]

  @npc_names [
    "Buzz",
    "Jody",
    "Chungye",
    "Hermod",
    "Pariz",
    "Lenya",
    "Gealuve",
    "Atila",
    "Diligo",
    "Ashin",
    "Others"
  ]

  @castle_maps [
    "aldeg_cas01",
    "aldeg_cas05",
    "gefg_cas01",
    "payg_cas03",
    "prtg_cas05",
    "prontera"
  ]

  # Town maps the shared helper tables key on (the Kafra teleport menu and its viewpoints).
  @maps [
    "prontera",
    "alberta",
    "aldebaran",
    "comodo",
    "cmd_fild07",
    "geffen",
    "izlude",
    "morocc",
    "umbala",
    "payon",
    "yuno",
    "job3_rune01",
    "niflheim"
  ]

  def seed, do: Process.get(:seed)
  def ints, do: :persistent_term.get(:h_ints)
  def atoms, do: :persistent_term.get(:h_atoms)

  def pick(key, domain), do: Enum.at(domain, rem(:erlang.phash2({seed(), key}), length(domain)))

  def counter(k) do
    c = Process.get({:counter, k}, 0)
    Process.put({:counter, k}, c + 1)
    c
  end

  def log(ctx, entry), do: %{ctx | log: [normalize(entry) | ctx.log]}

  # A logged callback (questinfo's condition fun) has a different identity in each
  # module copy, so compare its shape, not the closure.
  defp normalize(term) when is_function(term), do: :fun
  defp normalize(term) when is_list(term), do: Enum.map(term, &normalize/1)

  defp normalize(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.map(&normalize/1) |> List.to_tuple()

  defp normalize(term), do: term

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

  def call(:get_temp_var, [ctx, key, default]), do: Map.get(ctx.tempvars, key, default)
  def call(:get_temp_var, [ctx, key]), do: call(:get_temp_var, [ctx, key, 0])

  def call(:set_temp_var, [ctx, key, value]) do
    ctx |> log({:set_temp_var, key, value}) |> Map.update!(:tempvars, &Map.put(&1, key, value))
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

  # `getpartymember` fills $@partymembercount; party-size gates compare it to an integer.
  def call(:get_server_temp_var, [_ctx, key, default])
      when key in ["partymembercount", :partymembercount],
      do: pick({:gstv_party, key}, [default, 6, 8, 10, 6, 8])

  def call(:get_server_temp_var, [_ctx, key, default]),
    do: pick({:gstv, key}, [default, [], [1, 2], [150_001, 150_002, 150_003]])

  def call(:getpartymember, [ctx | args]),
    do: {log(ctx, {:getpartymember, args}), ["Party1", "Party2"]}

  # NPC placement identity: name (1) and the unique-name suffix (2).
  def call(:strnpcinfo, [_ctx, 1]), do: pick(:strnpcinfo1, @npc_names)

  # Server-persistent variables: election results, vote counters and feature flags.
  def call(:get_server_var, [_ctx, key, default]),
    do: pick({:gstv, key}, [default, 0, 1, 2, 3, 20])

  # `strnpcinfo(4)` is the NPC's map, the lookup key of map-keyed tables such as the Kafra menu.
  def call(:strnpcinfo, [_ctx, 4]), do: pick(:strnpcinfo4, @maps)

  def call(:strnpcinfo, [_ctx, _n]), do: pick(:strnpcinfo_n, ["01", "02", "03", "04", "05"])

  # Position of the talking unit; castle maps and their sibling suffixes are the gates here.
  def call(:getmapxy, [_ctx, kind]), do: {pick({:getmapxy, kind}, @castle_maps), 100, 100}

  def call(:castle_data, [_ctx, map, index]),
    do: pick({:castle_data, map, index}, [0, 0, 1, 2, 150_001, 150_002])

  def call(:is_guild_leader, [_ctx | args]), do: pick({:is_guild_leader, args}, [1, 0])

  def call(:gettimestr, [_ctx, format, _n]),
    do:
      pick({:gettimestr, format}, ["0001", "0101", "0201", "1015", "1230", "2200", "2300", "2359"])

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

    # Two thirds replay the last coloured dialog page (the usual "type the name you
    # were just given" guard); the rest explore the module's own short string
    # literals, which is the only way a keycard/password gate becomes reachable.
    n = counter(:input)

    v =
      if rem(:erlang.phash2({:input_guess?, seed(), n}), 3) != 0 do
        guess
      else
        pick({:input_pool, n}, short_strings() ++ ["wrong", 0, nil])
      end

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
  # The DSL answers 1/0, like rAthena: gates spell `== 0` for "would not fit".
  def call(:checkweight, [_ctx | args]), do: pick({:checkweight, args}, [1, 0])

  # 0 when unmarried; any other value when the player has a partner.
  def call(:getpartnerid, [_ctx | _args]), do: pick(:getpartnerid, [0, 150_001])
  def call(:can_change_job?, [_ctx | args]), do: pick({:ccj, args}, [true, false])

  # Renewal/classic switch: 1 in renewal, 0 otherwise.
  def call(:checkre, [_ctx | args]), do: pick({:checkre, args}, [0, 1])

  # Class bitmask; includes the baby flag (2_097_152) and the upper-class bits.
  def call(:eaclass, [_ctx]), do: pick(:eaclass, [0, 1, 768, 1_048_576, 2_097_152, 1_049_344])

  # Time components: hour values cover every day/night gate in the corpus.
  def call(:gettime, [_ctx, type]), do: pick({:gettime, type}, [0, 5, 12, 18, 21, 23])

  # The DSL answers 1/0 for these cart, falcon and riding checks, like rAthena.
  def call(name, [_ctx]) when name in [:checkcart, :checkfalcon, :checkriding],
    do: pick(name, [0, 1])

  def call(:finsertplural, [ctx | args]),
    do: {log(ctx, {:finsertplural, args}), "plural#{inspect(args)}"}

  def call(:fclearjobvar, [ctx | args]), do: {log(ctx, {:fclearjobvar, args}), nil}

  # Wall clock: `gettimetick(2)` is Unix epoch seconds, the form countdown NPCs subtract from.
  def call(:gettimetick, [_ctx, 2]), do: pick(:gettimetick, [0, 1000, 3600, 90_500])

  # Equipment reads: slot arguments are the rAthena `equip_index` ordinals.
  def call(:getequipid, [_ctx | args]), do: pick({:getequipid, args}, [-1, 0, 1201, 1202])

  def call(:getequiprefinerycnt, [_ctx | args]),
    do: pick({:getequiprefinerycnt, args}, [0, 1, 5, 10])

  def call(:getequipcardid, [_ctx | args]), do: pick({:getequipcardid, args}, [0, 4001, 4002])

  # `ITEMINFO_VIEW` (11) and `ITEMINFO_LOCATIONS` (5) cover the weapon and armor type lookups;
  # the locations domain includes the combined accessory masks.
  def call(:getiteminfo, [_ctx, _item, 11]),
    do: pick(:iteminfo_view, [0, 1, 2, 3, 8, 10, 16, 22, 99])

  def call(:getiteminfo, [_ctx, _item, 5]),
    do:
      pick(:iteminfo_locations, [
        0,
        1,
        2,
        3,
        4,
        8,
        16,
        32,
        64,
        128,
        136,
        256,
        512,
        1024,
        4096,
        8192,
        32_768,
        65_536,
        3_145_728
      ])

  def call(:getiteminfo, [_ctx, _item, _type]), do: 0

  # Value-returning global functions: the generated call keeps the `{ctx, value}` shape.
  def call(:fsexmes, [ctx, options]) when is_list(options),
    do: {log(ctx, {:fsexmes, options}), Enum.at(options, call(:sex, [ctx]), 0)}

  def call(:frand, [ctx, options]) when is_list(options) and options != [],
    do: {log(ctx, {:frand, options}), Enum.at(options, random(1..length(options)) - 1)}

  # Text helpers answer with a stable stand-in; the module under test is the one that
  # computes the real string, so its own branches are not duplicated here.
  def call(name, [ctx | args]) when name in [:fgetplural, :fgetarticle],
    do: {log(ctx, {name, args}), "#{name}#{inspect(args)}"}

  def call(name, [ctx | args]) when name in [:fgetweapontype, :fgetarmortype],
    do: {log(ctx, {name, args}), "#{name}#{inspect(args)}"}

  def call(:fcanopenstorage, [ctx | args]),
    do: {log(ctx, {:fcanopenstorage, args}), pick(:fcanopenstorage, [0, 1])}

  def call(name, [ctx | args]) when name in [:fcheckkafcode, :fsetkafcode],
    do: {log(ctx, {name, args}), nil}

  def call(:fcleargarbage, [ctx | args]), do: {log(ctx, {:fcleargarbage, args}), nil}

  # Service menus that hand the conversation on: their callers destructure the `{ctx, value}`
  # pair and ignore the value. `FKafra`/`FKafend` end the script at runtime; the model just
  # records the call so the caller's own flow stays comparable.
  def call(name, [ctx | args])
      when name in [:fkafset, :fkafra, :fkafend, :fmerckafra, :fvotekafra, :fcooleventcorp],
      do: {log(ctx, {name, args}), nil}

  def call(name, [%Ctx{} = ctx | args]) do
    if System.get_env("NPC_HARNESS_STRICT"),
      do: raise("unhandled ctx-first call #{name}/#{length(args) + 1}")

    log(ctx, {name, args})
  end

  def call(name, args), do: raise("unhandled #{name}/#{length(args)} #{inspect(args)}")

  # A thrown `{:script_end, ctx}` / `{:script_return, {ctx, value}}` carries the whole context,
  # but only its recorded effects are observable: locals are function-scoped and never survive
  # the unwinding, and every persistent write is logged as an effect.
  # A hand-written `on_talk`/`on_event` may return the `{ctx, value}` pair a global helper hands
  # back; the runtime `auto_close` unwraps it the same way.
  def returned_ctx({%Ctx{} = ctx, _value}), do: ctx
  def returned_ctx(%Ctx{} = ctx), do: ctx

  def ctx_payload(%Ctx{} = ctx), do: {:ctx, Enum.reverse(ctx.log)}

  def ctx_payload(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&ctx_payload/1) |> List.to_tuple()

  def ctx_payload(other), do: other

  def short_strings, do: :persistent_term.get(:h_strings)

  def rathena(:concat, [a, b]), do: to_string(a) <> to_string(b)
  def rathena(:atoi, [s]) when is_binary(s), do: s |> String.trim() |> String.to_integer()
  def rathena(:job_id, [id]) when is_integer(id), do: id
  def rathena(:job_id, [id]) when is_atom(id), do: :erlang.phash2(id)
  def rathena(:truthy?, [x]), do: x not in [0, "", false, nil]
  def rathena(:getitemname, [id]), do: "Item#{id}"
  def rathena(:bool_int, [b]), do: if(b, do: 1, else: 0)

  def rathena(:put_at, [list, index, value, _pad]) when index < length(list),
    do: List.replace_at(list, index, value)

  def rathena(:put_at, [list, index, value, pad]),
    do: list ++ List.duplicate(pad, index - length(list)) ++ [value]

  # Anything the harness does not model itself is the real project helper.
  def rathena(f, args) do
    if function_exported?(Aesir.ZoneServer.Script.Rathena, f, length(args)),
      do: apply(Aesir.ZoneServer.Script.Rathena, f, args),
      else: raise("unhandled Rathena.#{f} #{inspect(args)}")
  end

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
  defp drop?({:import, _, _}), do: true
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

# A scripted answer, not a dialog page: one short line of text the client could be
# asked to type back (keycard and password guards).
answer_like? = fn s ->
  String.length(s) in 1..32 and not String.contains?(s, "\n") and s =~ ~r/[A-Za-z]/
end

{ints, atoms, strings} =
  for path <- [old_path, new_path],
      reduce: {MapSet.new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99, -1]), MapSet.new(), MapSet.new()} do
    acc ->
      {:ok, ast} = Code.string_to_quoted(File.read!(path))

      {_, acc} =
        Macro.prewalk(ast, acc, fn
          i, {is, as, ss} when is_integer(i) and i >= -1 and i < 100_000 ->
            {i, {is |> MapSet.put(i - 1) |> MapSet.put(i) |> MapSet.put(i + 1), as, ss}}

          a, {is, as, ss} when is_atom(a) and a not in [nil, true, false] ->
            {a, {is, MapSet.put(as, a), ss}}

          s, {is, as, ss} when is_binary(s) ->
            {s, {is, as, if(answer_like?.(s), do: MapSet.put(ss, s), else: ss)}}

          node, acc ->
            {node, acc}
        end)

      acc
  end

:persistent_term.put(:h_ints, Enum.sort(ints))

:persistent_term.put(:h_strings, strings |> Enum.filter(answer_like?) |> Enum.sort())

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

# Global helpers take their arguments from the caller, so the shape and the values are
# drawn per seed from the literals both versions contain.
helper_args = fn seed ->
  ints = H.Core.ints()
  strings = H.Core.short_strings()

  num = fn tag -> Enum.at(ints, rem(:erlang.phash2({tag, seed}), length(ints))) end

  str = fn tag ->
    Enum.at(strings, rem(:erlang.phash2({tag, seed}), max(length(strings), 1)), "")
  end

  shapes = [
    fn -> [] end,
    fn -> [num.(:n0)] end,
    fn -> [str.(:s0)] end,
    fn -> [num.(:n0), num.(:n1)] end,
    fn -> [str.(:s0), num.(:n1)] end,
    fn -> [str.(:s0), num.(:n1), num.(:n2)] end,
    fn -> [str.(:s0), num.(:n1), num.(:n2), str.(:s3)] end,
    fn -> [num.(:n0), str.(:s1), num.(:n2)] end,
    fn -> [str.(:s0), str.(:s1)] end
  ]

  Enum.at(shapes, rem(seed, length(shapes))).()
end

run = fn mod, entry, seed ->
  Enum.each(Process.get_keys(), fn k -> if match?({:counter, _}, k), do: Process.delete(k) end)
  Process.put(:seed, seed)
  ctx = struct(Ctx, [])

  try do
    case entry do
      :talk ->
        {:ok, Enum.reverse(H.Core.returned_ctx(mod.on_talk(ctx)).log)}

      {:event, label} ->
        {:ok, Enum.reverse(H.Core.returned_ctx(mod.on_event(label, ctx)).log)}

      :call ->
        {ctx, value} = mod.call(ctx, helper_args.(seed))
        {:ok, Enum.reverse(ctx.log), if(is_struct(value, Ctx), do: :ctx, else: value)}
    end
  rescue
    e ->
      if debug? do
        IO.puts("#{inspect(mod)} #{inspect(entry)}: #{Exception.message(e)}")
        IO.puts(Exception.format(:error, e, __STACKTRACE__))
      end

      {:error, e.__struct__}
  catch
    # A transpiled `close`/`end` and `Ctx.halt/2` end the script by throwing this tag. The runtime
    # interaction catches it and keeps the ctx, so a clean end and a normal return are equivalent.
    :throw, {:script_end, ctx} ->
      if is_map(ctx) and Map.get(ctx, :__struct__) == Ctx do
        {:ok, Enum.reverse(ctx.log)}
      else
        {:caught, :throw, H.Core.ctx_payload({:script_end, ctx})}
      end

    kind, value ->
      {:caught, kind, H.Core.ctx_payload(value)}
  end
end

entries =
  cond do
    function_exported?(OldMod, :on_talk, 1) -> [:talk | Enum.map(old_labels, &{:event, &1})]
    function_exported?(OldMod, :call, 2) -> [:call]
    true -> Enum.map(old_labels, &{:event, &1})
  end

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

errors =
  paths
  |> Enum.filter(fn {_entry, result} -> match?({:error, _}, result) end)
  |> Enum.uniq()

IO.puts(
  "#{Path.basename(new_path)}: entries=#{length(entries)} distinct_paths=#{MapSet.size(paths)} " <>
    "mismatches=#{mismatches} error_outcomes=#{inspect(errors)}"
)
