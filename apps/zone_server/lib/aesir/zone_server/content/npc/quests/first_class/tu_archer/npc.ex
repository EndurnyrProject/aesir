defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.Npc do
  @moduledoc """
  Hidden target marker on the Archer training grounds; talking to it does nothing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "pay_arche",
        x: 76,
        y: 135,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Target"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
