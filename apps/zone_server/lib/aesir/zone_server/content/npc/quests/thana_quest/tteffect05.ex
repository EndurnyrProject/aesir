defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.Tteffect05 do
  @moduledoc """
  Displays a repeating spell effect in Thanatos Tower.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t12",
        x: 129,
        y: 56,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#tteffect05"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnStop", ctx), do: stopnpctimer(ctx)
  def on_event("OnTimer500", ctx), do: specialeffect(ctx, :beginspell7)
  def on_event("OnTimer1000", ctx), do: specialeffect(ctx, :beginspell7)
  def on_event("OnTimer1500", ctx), do: specialeffect(ctx, :beginspell7)
  def on_event("OnTimer2000", ctx), do: specialeffect(ctx, :beginspell7)
  def on_event("OnTimer2500", ctx), do: specialeffect(ctx, :beginspell7)
  def on_event("OnTimer3000", ctx), do: donpcevent(ctx, "#tteffect05::OnEnable")
end
