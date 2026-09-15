defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Yupi do
  @moduledoc """
  Warns that differently colored monster variants may be much stronger.

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
        map: "prontera",
        x: 160,
        y: 133,
        dir: 2,
        sprite: 102,
        name: "YuPi",
        scope: :shared,
        unique_name: "YuPi#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[YuPi]")
    |> mes(
      "Although many monsters may look the same, be careful! There are variations among monsters that have the same basic form."
    )
    |> next()
    |> mes("[YuPi]")
    |> mes(
      "One monster, that looks just like a peaceful and weak one that you've already encountered, may actually be wild and ferocious!"
    )
    |> next()
    |> mes("[YuPi]")
    |> mes(
      "You can tell these kinds of monsters apart by their body color. Wilder and more powerful monsters have more dangerous looking colors."
    )
    |> close()
  end
end
