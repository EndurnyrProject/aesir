defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Boatman93146 do
  @moduledoc """
  A boatman ferries adventurers between Hugel and the Odin Shrine.

  ## Behavior

  - Offers passage to the destination and preserves quest progression.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "odin_tem01", x: 93, y: 146, dir: 4, sprite: 709, name: "Boatman", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boatman]")
      |> mes("Ah, would you")
      |> mes("like to sail back to")
      |> mes("Hugel now, or did you")
      |> mes("want to explore a bit more?")
      |> next()
      |> select(["I still need to look around...", "Yes, take me back to Hugel."])

    case choice do
      1 -> decline(ctx)
      2 -> board(ctx)
      _ -> ctx
    end
  end

  defp decline(ctx) do
    ctx
    |> mes("[Boatman]")
    |> mes("Well, alright.")
    |> mes("Just let me know")
    |> mes("when you're ready to")
    |> mes("leave this dangerous place.")
    |> close()
  end

  defp board(ctx) do
    ctx
    |> mes("[Boatman]")
    |> mes("Alright then,")
    |> mes("climb aboard!")
    |> mes("We'll arrive near")
    |> mes("Hugel very soon~")
    |> close()
    |> warp("hugel", 206, 109)
  end
end
