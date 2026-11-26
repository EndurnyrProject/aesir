defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.SuspiciousLookingMan do
  @moduledoc """
  A restaurant patron shares his thoughts on food.

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
    spawn: [
      %{
        map: "ra_in01",
        x: 297,
        y: 50,
        dir: 7,
        sprite: 926,
        name: "Suspicious-Looking Man",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Suspicious-Looking Man]")
    |> mes("Each dish has its own")
    |> mes("unique taste that you must")
    |> mes("learn to relish. Of course,")
    |> mes("unhealthy junk food is the")
    |> mes("exception to this rule.")
    |> close()
  end
end
