defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Tono do
  @moduledoc """
  Explains the growth stages of Creamys and Peco Pecos.

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
        x: 54,
        y: 240,
        dir: 6,
        sprite: 97,
        name: "Tono",
        scope: :shared,
        unique_name: "Tono#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tono]")
    |> mes("Did you know?")
    |> next()
    |> mes("[Tono]")
    |> mes(
      "The larva of Creamy is Fabre. So, those green little wormy things are actually the babies of those pinkish, purply butterfly things you see around."
    )
    |> next()
    |> mes("[Tono]")
    |> mes(
      "But before Fabres can become Creamys, they go into a pupa stage. When that happens, they turn into these dark purple cocoons we call Pupa. Simple, huh?"
    )
    |> next()
    |> mes("[Tono]")
    |> mes("There's another monster that goes through a really big change... Pickys.")
    |> next()
    |> mes("[Tono]")
    |> mes(
      "Pickys are so cute when they're young, but when they grow up, they turn into those big, gawky looking Peco Pecos. Talk about awkward puberty."
    )
    |> close()
  end
end
