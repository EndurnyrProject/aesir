defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Find do
  @moduledoc """
  A dockside trigger offers a return trip to Whale Island.

  ## Behavior

  - Travelers who have progressed far enough can play the Gusli to reach the island.

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
        map: "moscovia",
        x: 136,
        y: 46,
        dir: 4,
        sprite: 844,
        name: "Find",
        scope: :shared,
        unique_name: "Find#ship",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :mos_whale_edq, 0) < 35 do
      ctx
    else
      offer_island_trip(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_island_trip(ctx) do
    ctx =
      ctx
      |> mes("-Watching the sea from the docks,")
      |> mes("it suddenly dawns upon you that you")
      |> mes("have memories from Whale Island.-")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Stop by the whale island?")
      |> next()
      |> select(["Go to Whale Island.", "Stay put."])

    if choice == 1 do
      ctx |> play_gusli() |> close()
    else
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I can go some other time.")
      |> mes("I will do other work now.")
      |> close()
    end
  end

  defp play_gusli(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2707)) do
      ctx
      |> soundeffect("mos_gusli2.wav", 0)
      |> mes("-Slowly, your hands are on the")
      |> mes("Gusli, and the playing starts...")
      |> mes("reminding you of the melody which")
      |> mes("the aged stranger had played...-")
      |> next()
      |> mes("[Village resident]")
      |> mes("So...something is rising from the sea!!!")
      |> next()
      |> mes("[Village Youth]")
      |> mes("What...What is that...??")
      |> next()
      |> mes("[Mr. Ibanoff]")
      |> mes("Ohohoh!... That's the whale")
      |> mes("island...!!! Someday, I hope to go there! Hahaha.")
      |> next()
      |> warp("mosk_fild01", 95, 93)
    else
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oh my goodness... Slipped right out")
        |> mes("of my mind... to forget equipping the Gusli.")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("The aged stranger said that when I")
      |> mes("want to go to Whale Island again, I")
      |> mes("should play the Gusli from this place...")
    end
  end
end
