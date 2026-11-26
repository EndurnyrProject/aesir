defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.CaveVos do
  @moduledoc """
  Announces Maheo's calls for help throughout the ice cave.

  ## Behavior

  - Cycles through three announcements at one-hour intervals.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ice_dun02",
        x: 120,
        y: 3,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#cave_vos"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTimer3600000", ctx), do: ev_ontimer3600000(ctx)
  def on_event("OnTimer7200000", ctx), do: ev_ontimer7200000(ctx)
  def on_event("OnTimer10800000", ctx), do: ev_ontimer10800000(ctx)
  @impl true
  def on_talk(ctx), do: ev_oninit(ctx)

  def ev_oninit(ctx), do: initnpctimer(ctx)

  def ev_ontimer3600000(ctx) do
    mapannounce(
      ctx,
      "ice_dun02",
      "Go away, you animals! I'll burn you to death once I get free!",
      1,
      16_764_416
    )
  end

  def ev_ontimer7200000(ctx) do
    mapannounce(
      ctx,
      "ice_dun02",
      "Hello? Can anyone hear me? I'm... I'm kind of stuck!",
      1,
      16_764_416
    )
  end

  def ev_ontimer10800000(ctx) do
    ctx
    |> stopnpctimer()
    |> mapannounce(
      "ice_dun02",
      "Please! I can't move! Hello? I think I might need help!",
      1,
      16_764_416
    )
    |> initnpctimer()
  end
end
