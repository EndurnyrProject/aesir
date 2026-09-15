defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.JunoFighter do
  @moduledoc """
  Describes Grand Peco behavior to visitors in Juno.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 328,
        y: 239,
        dir: 4,
        sprite: 732,
        name: "Juno Fighter",
        scope: :shared,
        unique_name: "Juno Fighter#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Sergiof]")
    |> mes("My name is Sergiof,")
    |> mes("the fighter who")
    |> mes("serves Granny.")
    |> next()
    |> mes("[Sergiof]")
    |> mes(
      "I will tell you about ^3355FFGrand Peco^000000 which is a high level Peco Peco. Grand Peco is faster than Peco Peco and is quite aggressive."
    )
    |> next()
    |> mes("[Sergiof]")
    |> mes(
      "It attacks using its strong bill and many Peco Pecos follow it. There's quite a difference in power between Peco Peco and the Grand Peco."
    )
    |> close()
  end
end
