defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Prst21 do
  @moduledoc """
  Warp portal from the demon temptation hall to the mummy hall of the Priest spiritual training.

  ## Behavior

  - Priests pass through freely.
  - An Acolyte passing through also enables the Mummy Generator.

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
        x: 168,
        y: 180,
        dir: 4,
        sprite: 45,
        name: "prst2_1",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        warp(ctx, "job_prist", 98, 40)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) ->
        ctx |> warp("job_prist", 98, 40) |> donpcevent("Mummy_Generator::OnEnable")

      true ->
        ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
