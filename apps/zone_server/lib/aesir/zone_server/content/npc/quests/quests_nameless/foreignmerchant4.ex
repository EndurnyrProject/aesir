defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Foreignmerchant4 do
  @moduledoc """
  Tracks the player's approach to the foreign merchant.

  ## Behavior

  - Advances the Arunafeltz quest from stage 3 to stage 4 on touch.

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
        x: 115,
        y: 147,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#ForeignMerchant4",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_em, 0) == 3 do
      set_char_var(ctx, :aru_em, 4)
    else
      ctx
    end
  end
end
