defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Dance do
  @moduledoc """
  Primary exit tile of the Dancer job test arena.

  ## Behavior

  - On touch, announces success, marks the dance test as passed, advances the quest log, and warps
    the player back to Comodo.
  - Enables and disables itself together with the other exit tiles.

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
  def on_event("OnTouch", ctx) do
    ctx
    |> mapannounce("job_duncer", "Good! Well done! Go back to Bijou!", 1)
    |> set_char_var(:DANC_Q, 9)
    |> changequest(7005, 7006)
    |> warp("comodo", 188, 162)
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> disablenpc("dance#return")
    |> donpcevent("dance#return#2::OnDisable")
    |> donpcevent("dance#return#3::OnDisable")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("dance#return") |> donpcevent("dance#return#2::OnEnable")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
