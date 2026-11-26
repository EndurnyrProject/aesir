defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.MemorySeal do
  @moduledoc """
  The memory seals summon guardians when their fragments are inserted.

  ## Behavior

  - Hides activated seals and counts defeated guardians.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Resolved EF_* effect constants that the generated module read as character variables, producing effect id 0.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thana_boss",
        x: 217,
        y: 167,
        dir: 3,
        sprite: 1711,
        name: "Memory Seal",
        scope: :shared,
        unique_name: "Memory Seal#tt1",
        trigger: {3, 3}
      },
      %{
        map: "thana_boss",
        x: 202,
        y: 75,
        dir: 3,
        sprite: 1712,
        name: "Memory Seal",
        scope: :shared,
        unique_name: "Memory Seal#tt2",
        trigger: {3, 3}
      },
      %{
        map: "thana_boss",
        x: 80,
        y: 76,
        dir: 7,
        sprite: 1709,
        name: "Memory Seal",
        scope: :shared,
        unique_name: "Memory Seal#tt3",
        trigger: {3, 3}
      },
      %{
        map: "thana_boss",
        x: 62,
        y: 171,
        dir: 5,
        sprite: 1710,
        name: "Memory Seal",
        scope: :shared,
        unique_name: "Memory Seal#tt4",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnMyMobDead", ctx) do
    ev_onmymobdead(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ev_onenable(ctx) do
    ctx |> hideoffnpc(strnpcinfo(ctx, 0)) |> set_npc_var("hide", 0)
  end

  defp ev_ondisable(ctx) do
    ctx |> hideonnpc(strnpcinfo(ctx, 0)) |> set_npc_var("hide", 0)
  end

  defp ev_ontouch(ctx) do
    seal = Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 2), 2))

    if Rathena.truthy?(:erlang.band(get_npc_var(ctx, "hide", 0), :erlang.bsl(1, seal))) do
      ctx
    else
      approach_seal(ctx, seal)
    end
  end

  defp approach_seal(ctx, seal) do
    {item, mob, x, y, effect, name} =
      case seal do
        1 -> {7437, 1711, 217, 167, :landprotector, "Misery"}
        2 -> {7436, 1712, 202, 75, :crashearth, "Agony"}
        3 -> {7438, 1709, 80, 76, :repairweapon, "Hatred"}
        4 -> {7439, 1710, 62, 171, :removetrap, "Despair"}
        _ -> {0, 0, 0, 0, 0, ""}
      end

    ctx = specialeffect(ctx, :gumgang)

    if get_server_temp_var(ctx, "thana_summon2", 0) > 3 do
      ctx
      |> mes("^3355FFYou cannot approach")
      |> mes("the crest because it is")
      |> mes("generating intense heat.^000000")
      |> close()
    else
      {ctx, input} =
        ctx
        |> mes("The seal seems to be dormant.")
        |> mes("There is a fragment missing from the crest of the Seal.")
        |> mes("Surely I saw a familiar fragment before...")
        |> next()
        |> input(:string)

      fragment = Rathena.concat("Fragment of ", name)

      if count_item(ctx, item) > 0 and fragment == input do
        ctx =
          ctx
          |> mes("^3355FFYou insert the")
          |> mes(fragment)
          |> mes("into the crest, causing")
          |> mes("its glow to intensify.^000000")
          |> close2()
          |> hideonnpc(strnpcinfo(ctx, 0))

        ctx =
          set_npc_var(ctx, "hide", :erlang.bor(get_npc_var(ctx, "hide", 0), :erlang.bsl(1, seal)))

        ctx = ctx |> delitem(item, 1) |> specialeffect(effect)

        ctx =
          summon_mob(ctx,
            mob_id: mob,
            map: "thana_boss",
            at: {x, y},
            name: name,
            event: Rathena.concat(strnpcinfo(ctx, 0), "::OnMyMobDead")
          )

        message =
          case get_server_temp_var(ctx, "thana_summon2", 0) do
            0 -> "... who... released... the... Memory... of... #{name}...?"
            1 -> "... why... did you... release... the... Memory... of... #{name}...?"
            2 -> "... ugh... stop it... the Memory of #{name}..."
            _ -> "... finally... you released the last piece of Memory..."
          end

        mapannounce(ctx, "thana_boss", message, 1, "0x7b68ee")
      else
        ctx
        |> mes("^3355FFThat action had no")
        |> mes("effect. You'll have to")
        |> mes("try something else.^000000")
        |> close()
      end
    end
  end

  defp ev_onmymobdead(ctx) do
    ctx =
      set_server_temp_var(ctx, "thana_summon2", get_server_temp_var(ctx, "thana_summon2", 0) + 1)

    if get_server_temp_var(ctx, "thana_summon2", 0) == 4 do
      mapwarp(ctx, "thana_boss", "thana_boss", 141, 228)
    else
      ctx
    end
  end
end
