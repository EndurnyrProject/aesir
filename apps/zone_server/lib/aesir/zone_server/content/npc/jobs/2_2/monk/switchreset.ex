defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Switchreset do
  @moduledoc """
  Manual switch that resets the Monk spirit maze monsters and restarts the reset timer.

  ## Behavior

  - Disables every maze spawner and re-enables the periodic resetter when clicked.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_test",
        x: 137,
        y: 338,
        dir: 1,
        sprite: 79,
        name: "switchreset",
        scope: :shared,
        unique_name: "switchreset#monkmonk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("Grrrr...")
    |> mes("All monsters in the monk job chance place have been reset.")
    |> mes("Timer's activated.")
    |> donpcevent("mob_monk#1_1::OnDisable")
    |> donpcevent("mob_monk#1_2::OnDisable")
    |> donpcevent("mob_monk#1_3::OnDisable")
    |> donpcevent("mob_monk#1_4::OnDisable")
    |> donpcevent("mob_monk#1_5::OnDisable")
    |> donpcevent("mob_monk#2_1::OnDisable")
    |> donpcevent("mob_monk#2_2::OnDisable")
    |> donpcevent("mob_monk#2_3::OnDisable")
    |> donpcevent("mob_monk#2_4::OnDisable")
    |> donpcevent("mob_monk#2_5::OnDisable")
    |> donpcevent("mob_monk#3_1::OnDisable")
    |> donpcevent("mob_monk#3_2::OnDisable")
    |> donpcevent("mob_monk#3_3::OnDisable")
    |> donpcevent("mob_monk#3_4::OnDisable")
    |> donpcevent("mob_monk#3_5::OnDisable")
    |> donpcevent("resetter#monk::OnEnable")
    |> close()
  end
end
