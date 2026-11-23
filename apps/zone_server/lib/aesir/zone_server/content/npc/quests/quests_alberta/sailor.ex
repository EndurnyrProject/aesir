defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Sailor do
  @moduledoc """
  Gotanblue offers a return trip from Turtle Island to Alberta.

  ## Behavior

  - Warps players to the mode-specific Alberta port when they accept.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tur_dun01",
        x: 165,
        y: 29,
        dir: 4,
        sprite: 709,
        name: "Sailor",
        scope: :shared,
        unique_name: "Sailor#tur2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gotanblue]")
      |> mes("Do you want")
      |> mes("to return")
      |> mes("to Alberta?")
      |> next()
      |> select(["Go to Alberta", "Stop talking"])

    ctx =
      if choice == 1 do
        ctx =
          ctx
          |> mes("[Gotanblue]")
          |> mes("Heh heh...")
          |> mes(
            "I certainly hope you've found what you were looking for. Alright, I guess there's always a time for an adventurer to return home..."
          )
          |> next()
          |> mes("^3355FF* Choo Choo *^000000")

        if Rathena.truthy?(checkre(ctx, 0)) do
          warp(ctx, "alberta", 238, 112)
        else
          warp(ctx, "alberta", 241, 115)
        end
      else
        ctx
      end

    close(ctx)
  end
end
