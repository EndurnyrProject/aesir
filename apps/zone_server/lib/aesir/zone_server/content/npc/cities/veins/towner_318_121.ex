defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner318121 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 318,
        y: 121,
        dir: 3,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve23"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("This storage solely")
    |> mes("exists for serious drinkers.")
    |> mes("If it's ever shut down,")
    |> mes("I think everyone in town")
    |> mes("will riot. Crazy, huh?")
    |> next()
    |> mes("[Towner]")
    |> mes("Veins is famous for its")
    |> mes("wide variety of delicious,")
    |> mes("irresistible liquor. Just one")
    |> mes("sip's enough to hook you.")
    |> next()
    |> mes("[Towner]")
    |> mes("Praise Freya for")
    |> mes("blessing us with the")
    |> mes("gift of awesome liquor.")
    |> mes("Her graciousness, her")
    |> mes("compassion, her liquor")
    |> mes("is limitless. Let us pray.")
    |> close()
  end
end
