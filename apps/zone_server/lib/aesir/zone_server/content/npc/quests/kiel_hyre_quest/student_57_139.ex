defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Student57139 do
  @moduledoc """
  Gui Nesha dismisses Laci's ghost stories and rumors.

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
        x: 57,
        y: 139,
        dir: 0,
        sprite: 893,
        name: "Student",
        scope: :shared,
        unique_name: "Student#khb"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Gui Nesha]")
    |> mes("Aren't we a little")
    |> mes("old to be talking about")
    |> mes("this kind of stuff? You")
    |> mes("know, rumors and ghost")
    |> mes("stories that make no sense?")
    |> mes("C'mon, Laci, knock it off!")
    |> emotion(:profusely_sweat)
    |> close()
  end
end
