defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.BankClerk do
  @moduledoc """
  Announces that the bank's services are temporarily unavailable.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 21,
        y: 38,
        dir: 7,
        sprite: 86,
        name: "Bank Clerk",
        scope: :shared,
        unique_name: "BankClerk"
      },
      %{
        map: "lhz_in02",
        x: 21,
        y: 25,
        dir: 7,
        sprite: 86,
        name: "Bank Clerk",
        scope: :shared,
        unique_name: "Bank Clerk#2"
      },
      %{
        map: "lhz_in02",
        x: 34,
        y: 22,
        dir: 1,
        sprite: 755,
        name: "Bank Clerk",
        scope: :shared,
        unique_name: "Bank Clerk#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bank Clerk]")
    |> mes("Due to some critical system")
    |> mes("errors, all of the bank services")
    |> mes("have been temporarily stopped.")
    |> mes("We apologize for any inconvenience and appreciate your understanding.")
    |> close()
  end
end
