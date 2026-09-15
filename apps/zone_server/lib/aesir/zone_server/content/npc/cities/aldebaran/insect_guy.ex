defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.InsectGuy do
  @moduledoc """
  Warns adventurers about insect monsters on Mt. Mjolnir.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 159,
        y: 242,
        dir: 4,
        sprite: 119,
        name: "Insect Guy",
        scope: :shared,
        unique_name: "Insect Guy#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Stromme]")
      |> mes(
        "Even to a strong Swordman, the Insects or Mt. Mjolnir pose a considerable threat. You've got to know your enemy before engaging it in battle!"
      )
      |> next()
      |> select(["About Insects", "End Conversation"])

    if choice == 1 do
      ctx
      |> mes("[Stromme]")
      |> mes(
        "Honey Bees, Butterflies and Moths seem like simple creatures, but that doesn't mean you should underestimate them."
      )
      |> next()
      |> mes("[Stromme]")
      |> mes(
        "These Insects have evolved over time, and can counter attacks from threats like you adventurers!"
      )
      |> next()
      |> mes("[Stromme]")
      |> mes(
        "There are also carnivorous Insects, such as praying Spiders, praying Mantises, and the millipede like Argiopes."
      )
      |> next()
      |> mes("[Stromme]")
      |> mes(
        "These monsters have mutated and are too strong for a person at certain levels. You should especially watch out for Argiopes."
      )
      |> next()
      |> mes("[Stromme]")
      |> mes(
        "Luckily, their eyesight is pretty bad, so it won't notice you if you walk a safe distance away from it."
      )
      |> close()
    else
      ctx
      |> mes("[Stromme]")
      |> mes("No matter how harmless and pretty insects are,")
      |> mes("take heed to not touch them.")
      |> mes("They are extremely strong unlike their innocent looking.")
      |> mes("Don't belittle the livings in the Mt. Mjolnir.")
      |> close()
    end
  end
end
