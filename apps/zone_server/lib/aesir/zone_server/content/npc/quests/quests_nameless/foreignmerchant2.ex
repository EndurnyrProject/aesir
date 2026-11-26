defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Foreignmerchant2 do
  @moduledoc """
  A hidden trigger advances the foreign merchant investigation.

  ## Behavior

  - Advances the quest or reveals the merchant based on quest progress and chance.

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
        x: 88,
        y: 136,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#ForeignMerchant2",
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
    case get_char_var(ctx, :aru_em, 0) do
      1 ->
        set_char_var(ctx, :aru_em, 2)

      5 ->
        ctx = set_local(ctx, :nawara, Enum.random(1..10))

        if get_local(ctx, :nawara, 0) < 5 do
          hideoffnpc(ctx, "Foreign Merchant#aru2")
        else
          set_char_var(ctx, :aru_em, 2)
        end

      _ ->
        ctx
    end
  end
end
