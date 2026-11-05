defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Mitchell do
  @moduledoc """
  Mitchell and her accompanying agents remain hidden until the final encounter summons them.

  ## Behavior

  - Hides each agent placement on initialization.

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
        x: 49,
        y: 55,
        dir: 6,
        sprite: 727,
        name: "Mitchell",
        scope: :shared,
        unique_name: "Mitchell#KiehlRoom"
      },
      %{
        map: "kh_kiehl02",
        x: 53,
        y: 52,
        dir: 4,
        sprite: 880,
        name: "Agent",
        scope: :shared,
        unique_name: "Agent#KHAgent1"
      },
      %{
        map: "kh_kiehl02",
        x: 51,
        y: 49,
        dir: 1,
        sprite: 880,
        name: "Agent",
        scope: :shared,
        unique_name: "Agent#KHAgent2"
      },
      %{
        map: "kh_kiehl02",
        x: 47,
        y: 50,
        dir: 0,
        sprite: 880,
        name: "Agent",
        scope: :shared,
        unique_name: "Agent#KHAgent3"
      },
      %{
        map: "kh_kiehl02",
        x: 46,
        y: 53,
        dir: 6,
        sprite: 880,
        name: "Agent",
        scope: :shared,
        unique_name: "Agent#KHAgent4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: hideonnpc(ctx, strnpcinfo(ctx, 0))

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
