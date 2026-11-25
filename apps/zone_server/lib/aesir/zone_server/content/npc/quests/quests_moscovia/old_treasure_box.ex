defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.OldTreasureBox do
  @moduledoc """
  A locked treasure box guarded by monsters.

  ## Behavior

  - Opens with the key and a mirror, or summons guards when the mirror is missing.
  - Re-enables the box when its guards die or the timer expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "treasure01",
        x: 165,
        y: 58,
        dir: 0,
        sprite: 111,
        name: "Old Treasure Box",
        scope: :shared,
        unique_name: "Old Treasure Box#rus37"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnCall", ctx) do
    ev_oncall(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer180000", ctx) do
    ev_ontimer180000(ctx)
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
    cond do
      max_weight(ctx) - weight(ctx) < 3500 ->
        ctx
        |> mes("You are carrying too much!")
        |> mes("Lose some weight and try again.")
        |> close()

      get_char_var(ctx, :rhea_rus_main, 0) > 20 and
          get_char_var(ctx, :rhea_rus_main, 0) < 25 ->
        ctx |> mes("- It is locked -") |> close()

      get_char_var(ctx, :rhea_rus_main, 0) == 25 ->
        open_box(ctx)

      get_char_var(ctx, :rhea_rus_main, 0) == 43 ->
        ctx |> mes("- The treasure box where you found the silver spoons -") |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp open_box(ctx) do
    ctx =
      ctx
      |> mes("- Around the locked box, a women having snakes on her head is engraved -")
      |> next()

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Does this work...")
      |> next()
      |> select(["Insert the key into the lock"])

    ctx =
      ctx
      |> mes(
        "- As soon as you insert the key into the lock, the eyes of the woman moves and she looks at you -"
      )
      |> next()
      |> mes("- Her eyes are made from jewels !! -")

    if Rathena.truthy?(count_item(ctx, 747)) do
      ctx = next(ctx)

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Arrrrrk? What is this!!")
      |> specialeffect(:flasher)
      |> next()
      |> mes(
        "- You wave your arms and cover your eyes. The mirror inside your bag reflects the light from her eyes accidentally !! -"
      )
      |> specialeffect(:flasher)
      |> next()
      |> mes(
        "- The light reflected goes to the woman shape and fumes comes from the box and it opens !! -"
      )
      |> next()
      |> mes("- ^0000ff You find Baba Yaga's spoon !!^000000 -")
      |> set_char_var(:rhea_rus_main, 43)
      |> give_item(7880, 1)
      |> close()
    else
      ctx
      |> sc_start(:sc_blind, 60000, 0)
      |> donpcevent("Old Treasure Box#rus37::OnCall")
      |> close2()
      |> donpcevent("Old Treasure Box#rus37::OnDisable")
    end
  end

  def ev_oncall(ctx) do
    ctx
    |> initnpctimer()
    |> summon_mob(
      mob_id: 1148,
      map: "treasure01",
      at: {164, 58},
      name: "Medusa",
      event: "Old Treasure Box#rus37::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1044,
      map: "treasure01",
      at: {157, 59},
      name: "Obeaune",
      event: "Old Treasure Box#rus37::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1044,
      map: "treasure01",
      at: {164, 54},
      name: "Obeaune",
      event: "Old Treasure Box#rus37::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1044,
      map: "treasure01",
      at: {163, 63},
      name: "Obeaune",
      event: "Old Treasure Box#rus37::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1044,
      map: "treasure01",
      at: {168, 59},
      name: "Obeaune",
      event: "Old Treasure Box#rus37::OnMyMobDead"
    )
  end

  def ev_ondisable(ctx) do
    ctx |> initnpctimer() |> disablenpc("Old Treasure Box#rus37")
  end

  def ev_ontimer180000(ctx) do
    ctx
    |> stopnpctimer()
    |> killmonster("treasure01", "Old Treasure Box#rus37::OnMyMobDead")
    |> ev_onmymobdead()
  end

  def ev_onmymobdead(ctx) do
    enablenpc(ctx, "Old Treasure Box#rus37")
  end
end
