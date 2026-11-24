defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.HanakoChan do
  @moduledoc """
  Startles visitors with a ghostly greeting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 34,
        y: 25,
        dir: 0,
        sprite: -1,
        name: "Hanako chan",
        scope: :shared,
        unique_name: "Hanako chan#ama",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: greeting(ctx)
  @impl true
  def on_talk(ctx) do
    greeting(ctx)
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Hanako chan]")
    |> mes(".......Eeeeheeheehee")
    |> mes(".....................")
    |> next()
    |> mes("[Hanako chan]")
    |> mes("..Eeeeheeheeheeheeheehee")
    |> mes("..........................")
    |> next()
    |> mes("[Hanako chan]")
    |> mes("......................")
    |> mes("...Want red toilet paper....")
    |> mes(".....or bl-ue toilet paper.... ")
    |> close()
  end
end
