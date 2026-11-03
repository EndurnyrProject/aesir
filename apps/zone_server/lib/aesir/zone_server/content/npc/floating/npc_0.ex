defmodule Aesir.ZoneServer.Content.Npc.Floating.Npc0 do
  @moduledoc """
  Floating touch trigger that sends the player to the Prontera Church during the Archer
  training quest.

  ## Behavior

  - On touch, once the palace conversation left the quest at step 6, shows the Minister's
    warning and advances the quest step to 7.
  - Stays silent for every other quest step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :tu_archer02, 0) == 6 do
      ctx
      |> mes("[Minister]")
      |> mes("Contact the")
      |> mes("Prontera Church.")
      |> mes("Hurry, this is urgent!")
      |> set_char_var(:tu_archer02, 7)
      |> close()
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
