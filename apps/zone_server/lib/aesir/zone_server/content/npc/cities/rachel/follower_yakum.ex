defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.FollowerYakum do
  @moduledoc """
  Remains absorbed in meditative prayer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temple",
        x: 115,
        y: 148,
        dir: 7,
        sprite: 916,
        name: "Follower Yakum",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Follower Yakum]")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("^3355FFShe is completely")
    |> mes("immersed in deep,")
    |> mes("meditative prayer.")
    |> mes("It'd be rude to")
    |> mes("disturb her now.^000000")
    |> close()
  end
end
