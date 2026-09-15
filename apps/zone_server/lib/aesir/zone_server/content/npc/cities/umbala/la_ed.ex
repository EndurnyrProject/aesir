defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.LaEd do
  @moduledoc """
  Represents the silent La Ed beside Haith's conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 170,
        y: 137,
        dir: 7,
        sprite: 84,
        name: "La Ed",
        scope: :shared,
        unique_name: "La Ed#um"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
