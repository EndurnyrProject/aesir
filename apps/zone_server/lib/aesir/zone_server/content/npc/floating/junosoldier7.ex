defmodule Aesir.ZoneServer.Content.Npc.Floating.Junosoldier7 do
  @moduledoc """
  Juno soldier who talks about the Crusader-only Sacred Mission shield.

  ## Behavior

  - Describes the narrow angel-winged shield and its strength against Devil and Undead monsters.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf
    - massdriller
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/yuno.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 263,
        y: 320,
        dir: 4,
        sprite: 852,
        name: "Juno Soldier",
        scope: :renewal,
        unique_name: "Juno Soldier#7juno"
      },
      %{
        map: "yuno",
        x: 263,
        y: 320,
        dir: 4,
        sprite: 105,
        name: "Juno Soldier",
        scope: :pre_renewal,
        unique_name: "Juno Soldier#7juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Juno Soldier]")
    |> mes("Welcome to Juno, the city of noble-mindedness.")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes("There is a holy shield named 'Sacred Mission' which can only be used by Crusaders.")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "It's a long and narrow shield with an angel wing engraved in the center of the front side. Against Devil and Undead monsters, it is especially powerful."
    )
    |> close()
  end
end
