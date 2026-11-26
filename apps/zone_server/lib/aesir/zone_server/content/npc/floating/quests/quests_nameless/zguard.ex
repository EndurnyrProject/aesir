defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsNameless.Zguard do
  @moduledoc """
  Controls the Z Gang guards and their encounter timer.

  ## Behavior

  - Spawns the guards and advances the encounter when they are defeated.
  - Resets the encounter and evacuates the map when the timer expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{name: "", scope: :shared, unique_name: "#ZGuard"}]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

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

  def on_event("OnReset", ctx) do
    ev_onreset(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnMyMobDead", ctx) do
    ev_onmymobdead(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer300000", ctx) do
    ev_ontimer300000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#ZGuard")
  end

  def ev_onenable(ctx) do
    ctx
    |> enablenpc("#ZGuard")
    |> initnpctimer()
    |> summon_mob(
      mob_id: 1479,
      map: "z_agit",
      at: {97, 78},
      name: "Catfoii's Guard",
      event: "#ZGuard::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1479,
      map: "z_agit",
      at: {98, 79},
      name: "Catfoii's Guard",
      event: "#ZGuard::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1523,
      map: "z_agit",
      at: {96, 81},
      name: "Catfoii's Guard",
      event: "#ZGuard::OnMyMobDead"
    )
  end

  def ev_ondisable(ctx) do
    ctx |> killmonster("z_agit", "#ZGuard::OnMyMobDead") |> stopnpctimer()
  end

  def ev_onreset(ctx) do
    ctx
    |> killmonster("z_agit", "#ZGuard::OnMyMobDead")
    |> set_server_temp_var("monster_zgang", 0)
  end

  def ev_onmymobdead(ctx) do
    if mobcount(ctx, "z_agit", "#ZGuard::OnMyMobDead") < 1 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You cowardly Z Gang!")
      |> mes("Come out and surrender!")
      |> mes("I've defeated your monster")
      |> mes("soldiers already!")
      |> next()
      |> mes("[Martha]")
      |> mes("What should we do?")
      |> next()
      |> mes("[Catfoii]")
      |> mes("This is our greatest")
      |> mes("crisis ever! I don't")
      |> mes("know what to do, meow!")
      |> next()
      |> mes("[Louis]")
      |> mes("The Z Gang's not going")
      |> mes("to surrender yet! Come")
      |> mes("forth, my loyal servants")
      |> mes("of the darkness!")
      |> next()
      |> mes("[Catfoii]")
      |> mes("No-no-no-meow!")
      |> mes("Not that button!")
      |> next()
      |> mes("[Louis]")
      |> mes("Huh? Why...?")
      |> next()
      |> set_char_var(:zdan_edq, 17)
      |> donpcevent("#ZGuard::OnDisable")
      |> hideoffnpc("Louis")
      |> hideoffnpc("Martha")
      |> hideoffnpc("Catfoii")
      |> close()
    else
      ctx
    end
  end

  def ev_ontimer300000(ctx) do
    ctx
    |> mapwarp("z_agit", "moc_fild17", 209, 235)
    |> donpcevent("#zdan_broad::OnDisable")
    |> killmonster("z_agit", "#ZGuard::OnMyMobDead")
    |> set_server_temp_var("monster_zgang", 0)
    |> set_server_temp_var("door2", 0)
    |> donpcevent("#ZGuard::OnDisable")
    |> stopnpctimer()
  end
end
