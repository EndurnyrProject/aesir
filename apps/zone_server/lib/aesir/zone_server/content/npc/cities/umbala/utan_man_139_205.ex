defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanMan139205 do
  @moduledoc """
  Welcomes visitors to Umbala's bungee jumping grounds and warns of their dangers.

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
        x: 139,
        y: 205,
        dir: 4,
        sprite: 785,
        name: "Utan Man",
        scope: :shared,
        unique_name: "Utan Man#5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("[Jooltan]")
      |> mes("It's been a long time since I last")
      |> mes("saw a Rune-Midgartsian~!")
      |> mes("Welcome, stranger.")
      |> next()
      |> mes("[Jooltan]")
      |> mes("We Utans use this place for")
      |> mes("bungee jumping. Many Utan")
      |> mes("youngsters have shown their")
      |> mes("bravery, earned their")
      |> mes("self-respect, and became")
      |> mes("adults in this very place.")
      |> next()
      |> mes("[Jooltan]")
      |> mes("Oh...right. A few unlucky people")
      |> mes("just fell and died after")
      |> mes("messing up their bungee jump. And")
      |> mes("a few had heart attacks while")
      |> mes("looking at other people jumping down...")
      |> next()
      |> mes("[Jooltan]")
      |> mes("So...")
      |> mes("Be careful when you walk around,")
      |> mes("You don't want to fall off.")
      |> mes("And if you want to try a bungee")
      |> mes("jump, you should get yourself ready.")
      |> next()
      |> mes("[Jooltan]")
      |> mes("Oh...right. Supposedly,")
      |> mes("there's an unidentified")
      |> mes("creature living in the water...")
      |> mes("So if you happen to get dunked,")
      |> mes("get out of there~!")
      |> close()
    else
      ctx
      |> mes("[???]")
      |> mes("Umbah umbah!")
      |> mes("Umbaumbah bababah umbah.")
      |> mes("Babaumm Utan umbah umbabah")
      |> mes("Umbaba hum.")
      |> mes("Umumhumbah umbaumbah umbabah.")
      |> next()
      |> mes("[???]")
      |> mes("Umbaum mahbababh umba,")
      |> mes("Umbabatan umbaumbah.")
      |> mes("Ba, umbaumbaumumbabaumm.")
      |> mes("Umbabah umbaumumum.")
      |> mes("Umbaumbaubahum.")
      |> close()
    end
  end
end
