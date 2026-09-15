defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanMan146157 do
  @moduledoc """
  Celebrates the courage of Utans who complete the bungee jump.

  ## Behavior

  - Speaks intelligibly only after Umbalan language progress reaches stage 3.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 146,
        y: 157,
        dir: 4,
        sprite: 786,
        name: "Utan Man",
        scope: :shared,
        unique_name: "Utan Man#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("[Arotan]")
      |> mes("Completing the bungee jump")
      |> mes("is very difficult to do.")
      |> mes("Today, we are here in celebration")
      |> mes("of the people that made it and")
      |> mes("have shown their courage.")
      |> close()
    else
      ctx
      |> mes("[???]")
      |> mes("Woo umbaumbaumbabah woo humbah")
      |> mes("Umbababah umba umba.")
      |> close()
    end
  end
end
