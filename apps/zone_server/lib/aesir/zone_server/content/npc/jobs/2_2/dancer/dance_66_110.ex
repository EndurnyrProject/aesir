defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Dance66110 do
  @moduledoc """
  Secondary exit tile of the Dancer job test arena.

  ## Behavior

  - On touch, marks the dance test as passed and warps the player back to Comodo.
  - Enables the next exit tile when it is enabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_duncer",
        x: 66,
        y: 110,
        dir: 0,
        sprite: -1,
        name: "dance",
        scope: :shared,
        unique_name: "dance#return#2",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: ctx |> set_char_var(:DANC_Q, 9) |> warp("comodo", 188, 162)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "dance#return#2")

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("dance#return#2") |> donpcevent("dance#return#3::OnEnable")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
