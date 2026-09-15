defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner218323 do
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
        map: "veins",
        x: 218,
        y: 323,
        dir: 1,
        sprite: 945,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve8"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Whoa, it's been a while")
    |> mes("seen I've seen tourists")
    |> mes("in town. You might think")
    |> mes("there's nothing here, but")
    |> mes("take a closer look. You")
    |> mes("might learn something.")
    |> next()
    |> mes("[Towner]")
    |> mes("Just like people, you")
    |> mes("can't know everything about")
    |> mes("a place with only a glance.")
    |> mes("If you give it a chance, I'm")
    |> mes("sure you'll find something")
    |> mes("to like about this town.")
    |> mes("and try to find things that mind interest you?")
    |> next()
    |> mes("[Towner]")
    |> mes("What do I mean by ''a")
    |> mes("closer look?'' Heh, you'll")
    |> mes("see... Maybe. Hahahaha!")
    |> mes("Oh, forget it, it's not")
    |> mes("that important anyway.")
    |> mes("May Freya bless you~")
    |> close()
  end
end
