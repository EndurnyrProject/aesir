defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Prst11 do
  @moduledoc """
  Warp portal that ends the zombie hall of the Priest spiritual training.

  ## Behavior

  - Priests pass through to the next hall freely.
  - Acolytes pass only once every zombie is dead, which resets the zombie hall and reopens
    Father Peter's entrance.

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
        x: 24,
        y: 109,
        dir: 4,
        sprite: 45,
        name: "prst1_1",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    mobs = get_npc_var_of(ctx, "MyMobs", "Zombie_Generator#prst", 0)

    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        warp(ctx, "job_prist", 168, 17)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) and mobs < 1 ->
        ctx
        |> warp("job_prist", 168, 17)
        |> donpcevent("Zombie_Generator#prst::OnDisable")
        |> donpcevent("Peter S. Alberto#2::OnDisable")
        |> donpcevent("Peter S. Alberto::OnEnable")
        |> donpcevent("Zombie_Generator#prst::OnDisable")

      true ->
        ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
