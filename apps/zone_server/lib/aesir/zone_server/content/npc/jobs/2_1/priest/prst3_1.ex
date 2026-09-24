defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Prst31 do
  @moduledoc """
  Warp portal that completes the Priest spiritual training and returns to the church.

  ## Behavior

  - Priests are warped back to the church.
  - Acolytes complete the spiritual training, advance the quest log, return to the church,
    and disable the Mummy Generator.

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
        x: 98,
        y: 105,
        dir: 4,
        sprite: 45,
        name: "prst3_1",
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
        warp(ctx, "prt_church", 15, 36)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) ->
        ctx
        |> set_char_var(:PRIEST_Q, 7)
        |> advance_training_quest()
        |> warp("prt_church", 16, 37)
        |> donpcevent("Mummy_Generator::OnDisable")

      true ->
        ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp advance_training_quest(ctx) do
    if checkquest(ctx, 8012) != -1 do
      changequest(ctx, 8012, 8013)
    else
      ctx
    end
  end
end
