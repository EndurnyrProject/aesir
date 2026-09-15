defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.UmbalaLady do
  @moduledoc """
  Tries to calm her excited child aboard the domestic airship.

  ## Behavior

  - Speaks normally after the player has progressed far enough in the Umbala language event.
  - Otherwise speaks in the Umbala language.

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
        map: "airplane",
        x: 66,
        y: 93,
        dir: 3,
        sprite: 783,
        name: "Umbala Lady",
        scope: :shared,
        unique_name: "Umbala Lady#ein_p"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> emotion(:think) |> mes("[Lady]")

    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("Shush...")
      |> mes("Honey, behave~")
      |> mes("Don't act so excited")
      |> mes("when we're out in a")
      |> mes("public place like this!")
      |> close()
    else
      ctx
      |> mes("Chooktu!")
      |> mes("Sacraup matii!")
      |> mes("Shaka gurftalfi")
      |> mes("huntiki manjoo!")
      |> close()
    end
  end
end
