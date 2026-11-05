defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Kiehl4853 do
  @moduledoc """
  This silent copy of Kiehl is hidden when initialized.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_kiehl02",
        x: 48,
        y: 53,
        dir: 6,
        sprite: 902,
        name: "Kiehl",
        scope: :shared,
        unique_name: "Kiehl#Copy"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    hideonnpc(ctx, "Kiehl#Copy")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
