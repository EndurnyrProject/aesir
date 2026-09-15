defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Blackboard do
  @moduledoc """
  Displays the messages scribbled on an office blackboard.

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
        map: "lhz_in01",
        x: 135,
        y: 57,
        dir: 3,
        sprite: 111,
        name: "Blackboard",
        scope: :shared,
        unique_name: "Blackboard#li"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFYou found a blackboard")
    |> mes("filled with scribbling. You")
    |> mes("can only read some of the")
    |> mes("messages that have been")
    |> mes("quickly scrawled on it.^000000")
    |> next()
    |> mes("''Make sure everything")
    |> mes("is complete by XX 00.''")
    |> mes("- Jorje")
    |> next()
    |> mes("Late Fee: 59, 990 zeny")
    |> next()
    |> mes("''I want to have''")
    |> mes("- Ellette")
    |> mes("''I want $$$ too!''")
    |> mes("- Enoz")
    |> mes("''How about @@@?''")
    |> mes("- Ellette")
    |> next()
    |> mes("''I wanna buy [#@$].''")
    |> mes("- Ninjose")
    |> mes("''Go buy it!''")
    |> mes("- Senyu")
    |> mes("''Working hard and buying hard")
    |> mes("is the best employee attitude.''")
    |> mes("- Mazwon")
    |> close()
  end
end
