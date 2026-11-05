defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Citizen289230 do
  @moduledoc """
  A citizen explains how reminders of life can restore memories to the dead.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vicious_Pucca
    - Reddozen
    - MasterOfMuppets
    - Silent
    - erKURITA
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 289,
        y: 230,
        dir: 3,
        sprite: 92,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#lv4-2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Citizen]")
    |> mes(
      "Meeting a person in the realm of the dead is impossible. But I've heard that if you were able to meet a dead person, you'd find that he wouldn't have all of his memories."
    )
    |> next()
    |> mes("[Citizen]")
    |> mes(
      "But if you brought him something that reminded him of his life, he'd get his memories back for a little while. Of course, you'd have to actually meet someone in the netherworld to find out for sure."
    )
    |> next()
    |> mes("[Citizen]")
    |> mes("Huh...")
    |> mes(
      "I know what I'm talking about might be a little morbid, but even the most trivial information might come in handy someday, right?"
    )
    |> close()
  end
end
