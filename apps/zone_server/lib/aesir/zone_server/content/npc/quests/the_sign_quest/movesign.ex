defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Movesign do
  @moduledoc """
  Lets adventurers follow a girl into the forest, moving them to a random maze location.

  ## Behavior

  - After the narration closes, rolls 1-10 and warps below 5, from 5 to 7, or above 7
    to one of three maze locations.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_maze02",
        x: 58,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#movesign",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou catch a glimpse")
      |> mes("of a girl heading directly")
      |> mes("into a deep forest. You decide")
      |> mes("to follow her and see if you can")
      |> mes("learn more.^000000")
      |> close2()

    case Enum.random(1..10) do
      roll when roll < 5 -> warp(ctx, "prt_maze02", 11, 146)
      roll when roll > 7 -> warp(ctx, "prt_maze03", 55, 8)
      _ -> warp(ctx, "prt_maze01", 62, 129)
    end
  end
end
