defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.TestTube do
  @moduledoc """
  A test tube contains a familiar-looking young man in an academy uniform.

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
        map: "kh_vila",
        x: 179,
        y: 68,
        dir: 0,
        sprite: 111,
        name: "Test Tube",
        scope: :shared,
        unique_name: "Test Tube#khp2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis test tube contains")
    |> mes("a young man dressed in")
    |> mes("a Kiel Hyre Academy")
    |> mes("uniform. Somehow, you")
    |> mes("get the feeling that you've")
    |> mes("seen him somewhere before.^000000")
    |> close()
  end
end
