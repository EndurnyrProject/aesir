defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanMan do
  @moduledoc """
  Explains the bungee jump's place in the Utan adulthood ceremony.

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
        x: 140,
        y: 157,
        dir: 6,
        sprite: 785,
        name: "Utan Man",
        scope: :shared,
        unique_name: "Utan Man#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("[Jertan]")
      |> mes("Bungee jumping can be dangerous,")
      |> mes("and you can risk your life doing")
      |> mes("it. We Utans have consider")
      |> mes("bungee jumping an important")
      |> mes("part of the ceremony of")
      |> mes("becoming an adult.")
      |> close()
    else
      ctx
      |> mes("[???]")
      |> mes("Umbaumbah humba.")
      |> mes("Woo umbaumbaumbabah woo humbah")
      |> mes("Umbababah umba umba.")
      |> close()
    end
  end
end
