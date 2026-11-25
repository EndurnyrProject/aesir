defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.TimeSpaceGap do
  @moduledoc """
  The time-space gap opens after Satan Morocc is defeated.

  ## Behavior

  - Eligible adventurers retrieve a fragment while the gap remains open; timers eventually close it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild21",
        x: 177,
        y: 239,
        dir: 0,
        sprite: 844,
        name: "Time-Space Gap",
        scope: :shared,
        unique_name: "Time-Space Gap#edq",
        trigger: {1, 1}
      }
    ]

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

  def on_event("OnTimer1800000", ctx) do
    ev_ontimer1800000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer21600000", ctx) do
    ev_ontimer21600000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rebirth_moc_edq, 0) == 4 and get_server_temp_var(ctx, "re_moc", 0) == 3 do
      ctx
      |> mes(
        "The time-space gap's frightening darkness seems to dissipate as Satan Morocc fades away."
      )
      |> next()
      |> mes(
        "You can see the fragments floating in the gap, and the radiating lights are now slowing their movement."
      )
      |> next()
      |> mes("You stretch your hand and pick up a lusterless fragment.")
      |> give_item(7820, 1)
      |> set_char_var(:rebirth_moc_edq, 6)
      |> changequest(3053, 3055)
      |> close()
    else
      ctx
      |> mes(
        "Slowly, erratically, the mysterious curtain of darkness casts over your eyes as you stare at the time-space gap."
      )
      |> next()
      |> mes("You feel like it's too dangerous to come any closer.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Time-Space Gap#edq")
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> enablenpc("Time-Space Gap#edq")
  end

  def ev_ondisable(ctx) do
    ctx
    |> stopnpctimer()
    |> disablenpc("Time-Space Gap#edq")
    |> donpcevent("Group of Evil#edq::OnEnable")
    |> set_server_temp_var("re_moc", 0)
  end

  def ev_ontimer1800000(ctx) do
    set_server_temp_var(ctx, "re_moc", 4)
  end

  def ev_ontimer21600000(ctx) do
    donpcevent(ctx, "Time-Space Gap#edq::OnDisable")
  end
end
