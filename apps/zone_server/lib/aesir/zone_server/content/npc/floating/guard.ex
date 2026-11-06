defmodule Aesir.ZoneServer.Content.Npc.Floating.Guard do
  @moduledoc """
  Prontera gate guard who greets everyone entering the capital.

  ## Behavior

  - Welcomes the player to Prontera.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/prontera.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 223,
        y: 99,
        dir: 1,
        sprite: 105,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#2pront"
      },
      %{
        map: "prontera",
        x: 229,
        y: 104,
        dir: 5,
        sprite: 105,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#3pront"
      },
      %{
        map: "prontera",
        x: 47,
        y: 339,
        dir: 5,
        sprite: 105,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#4pront"
      },
      %{
        map: "prontera",
        x: 52,
        y: 344,
        dir: 5,
        sprite: 105,
        name: "Guard",
        scope: :renewal,
        unique_name: "Guard#1pront"
      },
      %{
        map: "prontera",
        x: 160,
        y: 330,
        dir: 4,
        sprite: 105,
        name: "Guard",
        scope: :pre_renewal,
        unique_name: "Guard#5pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Prontera Guard]")
    |> mes("Welcome to Prontera.")
    |> close()
  end
end
