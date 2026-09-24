defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Resetter do
  @moduledoc """
  Periodically clears the monsters from every Monk spirit maze wing.

  ## Behavior

  - On each timer cycle, disables all maze spawners and restarts its timer.
  - Restarts its timer when enabled.

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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer500000", ctx) do
    ctx
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
    |> initnpctimer()
  end

  def on_event("OnInit", ctx), do: ctx
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
