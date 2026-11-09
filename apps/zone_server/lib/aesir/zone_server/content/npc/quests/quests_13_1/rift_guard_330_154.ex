defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.RiftGuard330154 do
  @moduledoc """
  Rift guard who points newcomers toward the head of the alliance at the dimensional rift.

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
        map: "moc_fild22b",
        x: 330,
        y: 154,
        dir: 3,
        sprite: 707,
        name: "Rift Guard",
        scope: :shared,
        unique_name: "Rift Guard#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Guard]")
    |> mes("Are you new here?")
    |> mes(
      "You look like you need to find the head of the alliance. You can find him near the center of the dimensional rift."
    )
    |> next()
    |> mes("[Guard]")
    |> mes("Just right there.")
    |> mes("There's a pillar of stone.")
    |> mes("Very close!")
    |> close()
  end
end
