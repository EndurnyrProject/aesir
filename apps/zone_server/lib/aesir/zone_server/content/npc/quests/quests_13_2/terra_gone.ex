defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.TerraGone do
  @moduledoc """
  Describes the empty cage left behind by Terra.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_in01",
        x: 71,
        y: 125,
        dir: 0,
        sprite: -1,
        name: "Terra gone",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: describe_cage(ctx)

  @impl true
  def on_talk(ctx), do: describe_cage(ctx)

  defp describe_cage(ctx) do
    ctx
    |> mes("There's nothing else.")
    |> mes("Only traces of the cage with something confined.")
    |> close()
  end
end
