defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.YoungMan do
  @moduledoc """
  Describes the mine’s monster problem and begs adventurers for help.

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
        map: "einbech",
        x: 197,
        y: 139,
        dir: 4,
        sprite: 855,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#air2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Heinz]")
    |> mes("Wow...")
    |> mes("An adventurer from")
    |> mes("Rune-Midgarts, eh?")
    |> mes("What brings you here?")
    |> next()
    |> mes("[Heinz]")
    |> mes("Einbech doesn't offer much")
    |> mes("in terms of sight-seeing, but")
    |> mes("have you come to see the mine?")
    |> mes("Right now, it's swarming with")
    |> mes("monsters and we can't dig any")
    |> mes("ores because it's so dangerous.")
    |> next()
    |> mes("[Heinz]")
    |> mes("Now, if some adventurers were")
    |> mes("generous enough to hunt down")
    |> mes(
      "those evil creatures, we'd be able to mine again and they could earn some extra zeny. It's like killing two birds with one stone. Hahaha!"
    )
    |> next()
    |> mes("[Heinz]")
    |> mes("Oh wait... I'm sorry.")
    |> mes("I don't know what's wrong")
    |> mes("with me, asking complete")
    |> mes("strangers to do favors for")
    |> mes("me. It's completely rude!")
    |> mes("I mean, who would do that?")
    |> next()
    |> mes("[Heinz]")
    |> mes("But... I'm beyond caring")
    |> mes("about my pride. For the sake")
    |> mes(
      "of all that is good and holy, I'm begging you, please kill those foul and evil creatures. Please~!"
    )
    |> close()
  end
end
