defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.PowerfulLookingGuy do
  @moduledoc """
  Explains the spiritual preparation needed before martial arts training.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 274,
        y: 136,
        dir: 4,
        sprite: 819,
        name: "Powerful-looking guy",
        scope: :shared,
        unique_name: "Powerful-looking guy#lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Akiira]")
    |> mes(
      "I am practicing my 'Claw of Dragon.' I not only need to use the power of my fists, I must also condition myself spiritually."
    )
    |> next()
    |> mes("[Akiira]")
    |> mes("Every martial art requires")
    |> mes("spiritual training since the")
    |> mes("mind controls the body.")
    |> mes("If you've trained yourself spiritually, you can easily")
    |> mes("use any part of the body!")
    |> next()
    |> mes("[Akiira]")
    |> mes("If you are considering")
    |> mes("studying the martial arts, you should first attain knowledge before jumping into the")
    |> mes("physical training.")
    |> next()
    |> mes("[Akiira]")
    |> mes("Learn about the martial arts")
    |> mes(
      "and meditate on life's truths. First, you must find peace of mind before you can hope to master the mind and body."
    )
    |> close()
  end
end
