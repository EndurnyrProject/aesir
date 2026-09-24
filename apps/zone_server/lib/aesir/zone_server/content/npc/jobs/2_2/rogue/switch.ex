defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.Switch do
  @moduledoc """
  Resets the monsters of the Rogue job test tunnel on demand.

  ## Behavior

  - Disables every tunnel ambush trigger and restarts the periodic resetter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 399,
        y: 286,
        dir: 1,
        sprite: 88,
        name: "switch",
        scope: :shared,
        unique_name: "switch#rogreset"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^F08080Tah dah~")
    |> mes("Monsters for the")
    |> mes("Rogue Job Change")
    |> mes("have been reset^000000.")
    |> donpcevent("mob_rogue#1::OnDisable")
    |> donpcevent("mob_rogue#2::OnDisable")
    |> donpcevent("mob_rogue#3::OnDisable")
    |> donpcevent("mob_rogue#4::OnDisable")
    |> donpcevent("mob_rogue#5::OnDisable")
    |> donpcevent("mob_rogue#6::OnDisable")
    |> donpcevent("mob_rogue#7::OnDisable")
    |> donpcevent("mob_rogue#8::OnDisable")
    |> donpcevent("mob_rogue#9::OnDisable")
    |> donpcevent("mob_rogue#10::OnDisable")
    |> donpcevent("mob_rogue#12::OnDisable")
    |> donpcevent("mob_rogue#13::OnDisable")
    |> donpcevent("mob_rogue#15::OnDisable")
    |> donpcevent("resetter#rogue::OnEnable")
    |> close()
  end
end
