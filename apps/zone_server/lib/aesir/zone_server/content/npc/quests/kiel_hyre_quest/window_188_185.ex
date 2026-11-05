defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Window188185 do
  @moduledoc """
  This academy window leads outside.

  ## Behavior

  - Transfers the adventurer outside the academy.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_school",
        x: 188,
        y: 185,
        dir: 0,
        sprite: 111,
        name: "Window",
        scope: :shared,
        unique_name: "Window#kh2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    warp(ctx, "yuno_fild08", 69, 183)
  end
end
