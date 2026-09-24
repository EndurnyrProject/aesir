defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Dance72110 do
  @moduledoc """
  Final exit tile of the Dancer job test arena.

  ## Behavior

  - On touch, marks the dance test as passed and warps the player back to Comodo.
  - When enabled, stops the dance test timer and reopens the waiting room.

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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: ctx |> set_char_var(:DANC_Q, 9) |> warp("comodo", 188, 162)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "dance#return#3")

  def on_event("OnEnable", ctx) do
    ctx
    |> enablenpc("dance#return#3")
    |> donpcevent("Bijou#dance_timer::OnDisable")
    |> donpcevent("Waiting Room#dance::OnEnable")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
