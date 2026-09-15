defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.UmbalaKid do
  @moduledoc """
  Reacts excitedly to flying aboard the domestic airship.

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
        x: 64,
        y: 94,
        dir: 1,
        sprite: 787,
        name: "Umbala Kid",
        scope: :shared,
        unique_name: "Umbala Kid#ein_p"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> emotion(:profusely_sweat) |> mes("[Kid]")

    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("Wow, mom!")
      |> mes("L-look at this!")
      |> mes("We're flying! W-we're...")
      |> mes("We're in the freakin' sky!")
      |> close()
    else
      ctx
      |> mes("Makumalagu!")
      |> mes("Saampa joojimbo")
      |> mes("kaku na jedi Solo.")
      |> mes("Bwahahahahahahaah!")
      |> close()
    end
  end
end
