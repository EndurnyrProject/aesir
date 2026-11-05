defmodule Aesir.ZoneServer.Content.Npc.Quests.Lvl4WeaponQuest.Citizen do
  @moduledoc """
  A citizen recounts the tragedy of a weaponsmith and his four sons.

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
        map: "geffen",
        x: 203,
        y: 146,
        dir: 5,
        sprite: 97,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#lv4-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Citizen]")
    |> mes("There was a skillful")
    |> mes("weaponsmith in Al De Baran")
    |> mes(
      "who had 4 sons. All of them were known throughout the land for their skill in weapon crafting."
    )
    |> next()
    |> mes("[Citizen]")
    |> mes(
      "Tragically, all of the sons died in their attempt to create a powerful weapon. Only the father survived the accident."
    )
    |> next()
    |> mes("[Citizen]")
    |> mes(
      "Because of that incident, the weaponsmith retired and went into hiding. No one ever saw the weapon he and his sons were developing."
    )
    |> next()
    |> mes("[Citizen]")
    |> mes("I don't think his sons")
    |> mes(
      "were able to peacefully enter the afterlife after sacrificing so much and having to leave their goal unfulfilled..."
    )
    |> close()
  end
end
