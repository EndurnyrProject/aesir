defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.QueGodnpc1Godentrance do
  @moduledoc """
  Entrance notice of the god item laboratory.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 214,
        y: 128,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: "GodEntrance",
        hidden_name: "que_godnpc1"
      },
      %{
        map: "que_god01",
        x: 215,
        y: 128,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #que_godnpc2"
      },
      %{
        map: "que_god01",
        x: 213,
        y: 128,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #que_godnpc3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Entrance Notice]")
    |> mes("Only the most")
    |> mes("worthy of humans")
    |> mes("will possess the")
    |> mes("power of the gods.")
    |> close()
  end
end
