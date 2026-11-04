defmodule Aesir.ZoneServer.Content.Npc.Floating.Wickebine do
  @moduledoc """
  The hidden Wickebine placeholder of the cooking quest, kept disabled so only the placement
  that the quest enables is ever visible.

  ## Behavior

  - Disables the `Wickebine#cook` NPC on talk, on init and on its disable event.
  - Re-enables it on the enable event.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Reddozen
    - L0ne_W0lf
    - Lupus
    - Samuray22
    - ultramage
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Wickebine#cook")
  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Wickebine#cook")
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Wickebine#cook")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: disablenpc(ctx, "Wickebine#cook")
end
