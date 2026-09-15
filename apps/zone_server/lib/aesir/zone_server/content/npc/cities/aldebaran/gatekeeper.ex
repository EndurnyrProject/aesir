defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Gatekeeper do
  @moduledoc """
  Controls passage to the fourth floor of the Clock Tower.

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
        map: "c_tower3",
        x: 10,
        y: 249,
        dir: 4,
        sprite: 84,
        name: "Gatekeeper",
        scope: :shared,
        unique_name: "Gatekeeper#ct"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} =
      Aesir.ZoneServer.Content.Npc.Functions.FClocktowergate.call(ctx, [
        "4th",
        7026,
        "c_tower4",
        185,
        44
      ])

    ctx
  end
end
