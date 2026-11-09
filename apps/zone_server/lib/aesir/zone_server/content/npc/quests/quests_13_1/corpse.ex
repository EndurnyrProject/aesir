defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Corpse do
  @moduledoc """
  The Dandelion member's corpse in the Morocc hideout, searched for the clue Rin's fight left
  behind.

  ## Behavior

  - Refuses a player who cannot pick up an item, and one who still has gangers alive nearby.
  - At `mao_morocc2` step 10 offers to check the pockets or shake the corpse; either way the
    Sealed Magic Scroll falls out, the step becomes 11, quest 7020 advances to 7021, the hideout
    trigger stops and this corpse starts its own timer.
  - At step 11 identifies the corpse as Rin's victim, and on any other step warps the player out
    of the hideout.
  - On call summons the five gangers at their spots, and its timers announce the search, warp the
    hideout to the camp and clear the whole scene.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_dan01",
        x: 49,
        y: 36,
        dir: 5,
        sprite: 457,
        name: "Corpse",
        scope: :shared,
        unique_name: "Corpse#moc2_dead01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Corpse#moc2_dead01"
  @map "que_dan01"
  @mob_event "Corpse#moc2_dead01::OnMyMobDead"
  @ganger 1985

  @ganger_spots [{26, 40}, {21, 35}, {25, 32}, {34, 34}, {36, 34}]

  @sealed_scroll 6028

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{714, 1}]) == 0 ->
        overburdened(ctx)

      mobcount(ctx, @map, @mob_event) > 0 ->
        enemies_first(ctx)

      get_char_var(ctx, :mao_morocc2, 0) == 10 ->
        search_the_body(ctx)

      get_char_var(ctx, :mao_morocc2, 0) == 11 ->
        rins_victim(ctx)

      true ->
        unnatural_corpse(ctx)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
  def on_event("OnCall", ctx), do: summon_gangers(ctx)
  def on_event("OnMyMobDead", ctx), do: ctx
  def on_event("OnReset", ctx), do: killmonster(ctx, @map, @mob_event)

  def on_event("OnTimer4000", ctx) do
    mapannounce(ctx, @map, "...Hey!... Where are you?!... Where did you go?!!!", 1, "0xdda0dd")
  end

  def on_event("OnTimer7000", ctx), do: mapwarp(ctx, @map, "mid_camp", 204, 312)
  def on_event("OnTimer10000", ctx), do: clear_the_scene(ctx)
  def on_event("OnTimer11000", ctx), do: set_server_temp_var(ctx, "moc_mao_gate1", 0)

  defp overburdened(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp enemies_first(ctx) do
    ctx
    |> mes("Now's not the time to examine corpses.")
    |> mes("You better take care of your living enemies first!")
    |> close()
  end

  defp search_the_body(ctx) do
    {ctx, choice} =
      ctx
      |> mes("You have found a laceration on the dead body;")
      |> mes("he must have been killed by Rin.")
      |> next()
      |> select(["Check his pockets.", "Shake the corpse."])

    case choice do
      1 ->
        ctx
        |> mes(
          "It's creepy to touch a corpse, but you have decided to check his pockets for any clues."
        )
        |> next()
        |> finds_the_scroll()

      2 ->
        ctx
        |> mes("It's creepy to touch a corpse, but you have decided to shake and turn the body")
        |> mes("to find any possible clues")
        |> mes("And...")
        |> next()
        |> finds_the_scroll()

      _cancelled ->
        ctx
    end
  end

  defp finds_the_scroll(ctx) do
    ctx
    |> mes("A scroll flew out of the body's jacket pocket.")
    |> mes("You're not sure what this scroll is for, but obviously it seems pretty important.")
    |> next()
    |> mes("^4d4dffYou have obtained a Sealed Magic Scroll.")
    |> mes("Let's bring this to Kidd.^000000")
    |> set_char_var(:mao_morocc2, 11)
    |> give_item(@sealed_scroll, 1)
    |> donpcevent("#moc2_event_on::OnStop")
    |> initnpctimer()
    |> changequest(7020, 7021)
    |> close()
  end

  defp rins_victim(ctx) do
    ctx
    |> mes("You have found a Dandelion Member who was killed by Rin.")
    |> close()
  end

  defp unnatural_corpse(ctx) do
    ctx
    |> mes("It's just a corpse, but there seems to be something unnatural about it.")
    |> close()
    |> warp("morocc", 104, 108)
  end

  defp summon_gangers(ctx) do
    Enum.reduce(@ganger_spots, ctx, fn {x, y}, ctx ->
      summon_mob(ctx, mob_id: @ganger, map: @map, at: {x, y}, event: @mob_event)
    end)
  end

  defp clear_the_scene(ctx) do
    ctx
    |> donpcevent("#{@npc}::OnDisable")
    |> donpcevent("Rin#moc2_bt_rin01::OnDisable")
    |> donpcevent("Rin#moc2_bt_rin02::OnDisable")
    |> donpcevent("Rayan#moc2_bt_r01::OnDisable")
    |> donpcevent("Dandelion Member#moc2_1::OnDisable")
    |> donpcevent("Dandelion Member#moc2_2::OnDisable")
    |> donpcevent("Dandelion Member#moc2_3::OnDisable")
    |> donpcevent("Dandelion Member#moc2_4::OnDisable")
    |> donpcevent("Dandelion Member#moc2_5::OnDisable")
    |> donpcevent("#moc2_event01::OnDisable")
    |> donpcevent("#moc2_event_on::OnEnable")
  end
end
