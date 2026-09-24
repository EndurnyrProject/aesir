defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Trap do
  @moduledoc """
  Catches Monk marathon runners who stray off course and sends them back to the start.

  ## Behavior

  - Announces the trapped runner on the test map and warps them to the marathon start.

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
  def on_event("OnTouch", ctx) do
    ctx
    |> mapannounce("monk_test", "#{char_name(ctx, 0)}, you're trapped. You will be returned.", 1)
    |> warp("monk_test", 387, 387)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
