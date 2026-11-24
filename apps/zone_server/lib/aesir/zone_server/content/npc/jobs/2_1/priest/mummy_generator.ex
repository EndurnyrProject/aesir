defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.MummyGenerator do
  @moduledoc """
  Controls the mummy waves in the Priest spiritual training.

  ## Behavior

  - Starts disabled; enabling it arms the three mummy wave triggers.
  - Each wave event summons a pair of Mummies in the training hall.
  - Disabling it hides the generator and kills every monster in the training map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 1,
        y: 2,
        dir: 1,
        sprite: 110,
        name: "Mummy_Generator",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @mummy 1041

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Mummy_Generator")

  def on_event("OnEnable", ctx) do
    ctx
    |> donpcevent("Mummy1_1::OnEnable")
    |> donpcevent("Mummy2_1::OnEnable")
    |> donpcevent("Mummy3_1::OnEnable")
  end

  def on_event("Onm1", ctx), do: summon_pair(ctx, 55, "Khamoz", "Amocsis")
  def on_event("Onm2", ctx), do: summon_pair(ctx, 70, "Mentuhoteph", "Akenaten")
  def on_event("Onm3", ctx), do: summon_pair(ctx, 85, "Mehnes", "Snepheru")

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Mummy_Generator") |> killmonsterall("job_prist")
  end

  @impl true
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnInit", ctx)

  defp summon_pair(ctx, y, first_name, second_name) do
    ctx
    |> summon_mob(mob_id: @mummy, map: "job_prist", at: {90, y}, name: first_name)
    |> summon_mob(mob_id: @mummy, map: "job_prist", at: {105, y}, name: second_name)
  end
end
