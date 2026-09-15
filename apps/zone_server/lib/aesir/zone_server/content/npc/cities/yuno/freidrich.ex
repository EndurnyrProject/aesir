defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.Freidrich do
  @moduledoc """
  Explains Juno's history, geography, and ancient power source.

  ## Behavior

  - Randomly describes either Juno's islands or the ancient power that keeps the city aloft.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 184,
        y: 173,
        dir: 4,
        sprite: 729,
        name: "Freidrich",
        scope: :shared,
        unique_name: "Freidrich#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Enum.random(1..5) == 1 do
      explain_junos_power(ctx)
    else
      explain_junos_islands(ctx)
    end
  end

  defp explain_junos_power(ctx) do
    ctx
    |> mes("[Freidrich]")
    |> mes("^3355FFJuno^000000 is kept aloft in the air by an ancient and mysterious force.")
    |> next()
    |> mes("[Freidrich]")
    |> mes(
      "This power is said to come from a relic from an ancient civilization called ^3355FFJuperos^000000 which existed here long before Juno."
    )
    |> next()
    |> mes("[Freidrich]")
    |> mes(
      "Research revealed that Juno's power source based on ^3355FFPieces of Ymir's Heart^000000. I hear that this power source is found where Juperos used to exist."
    )
    |> next()
    |> mes("[Freidrich]")
    |> mes(
      "Since many scholars have been coming to Juno to study and research this power source, our city is basically a well known mecca for scholars."
    )
    |> close()
  end

  defp explain_junos_islands(ctx) do
    ctx
    |> mes("[Freidrich]")
    |> mes("The city of Sages,")
    |> mes("^3355FFJuno,^000000 is made of")
    |> mes("three islands.")
    |> next()
    |> mes("[Freidrich]")
    |> mes(
      "These are Solomon, the island of honor, Mineta, the island of prosperity, and Snotora, the island of knowledge."
    )
    |> next()
    |> mes("[Freidrich]")
    |> mes("The location of each island is")
    |> mes("North-west : Solomon")
    |> mes("North-east : Snotora")
    |> mes("South : Mineta.")
    |> close()
  end
end
