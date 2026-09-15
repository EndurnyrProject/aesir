defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.Bonubonu do
  @moduledoc """
  Represents the silent form of Bonubonu beside Amatsu's legendary tree.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 283,
        y: 203,
        dir: 1,
        sprite: 1323,
        name: "Bonubonu",
        scope: :shared,
        unique_name: "Bonubonu#ama1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
