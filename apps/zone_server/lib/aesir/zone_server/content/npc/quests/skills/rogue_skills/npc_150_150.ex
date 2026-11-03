defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.Npc150150 do
  @moduledoc """
  Hidden trigger that starts the Close Confine training round when a player enters the arena.

  ## Behavior

  - On touch, enables the five-minute arena timer and the Kienna movement timer, then hides itself.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> donpcevent("#1st5min::OnEnable")
    |> donpcevent("#1stmove::OnEnable")
    |> disablenpc("#1strecog")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
