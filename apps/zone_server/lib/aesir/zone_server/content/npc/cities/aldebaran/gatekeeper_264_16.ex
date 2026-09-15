defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Gatekeeper26416 do
  @moduledoc """
  Controls passage to the fourth basement of the Clock Tower.

  ## Behavior

  - Explains the sealed passage and consumes the required key before warping eligible visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alde_dun03",
        x: 264,
        y: 16,
        dir: 4,
        sprite: 101,
        name: "Gatekeeper",
        scope: :shared,
        unique_name: "Gatekeeper#ct1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} =
      Aesir.ZoneServer.Content.Npc.Functions.FClocktowergate.call(ctx, [
        "B4th",
        7027,
        "alde_dun04",
        79,
        267
      ])

    ctx
  end
end
