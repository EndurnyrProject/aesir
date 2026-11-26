defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Foreignmerchant1 do
  @moduledoc """
  A hidden trigger advances the Peace for Arunafeltz quest.

  ## Behavior

  - Advances the quest when the player enters the area at the required stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 86,
        y: 149,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#ForeignMerchant1",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_em, 0) == 4 do
      set_char_var(ctx, :aru_em, 5)
    else
      ctx
    end
  end
end
