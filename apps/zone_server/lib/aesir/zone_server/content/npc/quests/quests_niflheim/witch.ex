defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Witch do
  @moduledoc """
  Kirkena, a Niflheim witch who sends living visitors back to Umbala.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nif_in",
        x: 188,
        y: 168,
        dir: 3,
        sprite: 792,
        name: "Witch",
        scope: :shared,
        unique_name: "Witch#nif"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Kirkena]")
    |> mes("Huh? ...You're alive, aren't you?")
    |> mes("I'm not sure how more of you are")
    |> mes("able to get here and I don't")
    |> mes("know your reasons for coming,")
    |> mes("but this place is dangerous for")
    |> mes("the living.")
    |> next()
    |> mes("[Kirkena]")
    |> mes("I am sending you back")
    |> mes("outside of this town.")
    |> mes("If you can help it, you")
    |> mes("better not come back to")
    |> mes("this place.")
    |> close2()
    |> warp("umbala", 138, 208)
  end
end
