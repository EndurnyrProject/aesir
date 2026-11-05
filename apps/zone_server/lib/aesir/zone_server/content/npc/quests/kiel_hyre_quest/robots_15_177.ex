defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Robots15177 do
  @moduledoc """
  These silent robots stand in Kiehl’s rooms without responding to conversation.

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
        map: "kh_kiehl01",
        x: 15,
        y: 177,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "RobotsKHQ"
      },
      %{
        map: "kh_kiehl01",
        x: 15,
        y: 180,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh3"
      },
      %{
        map: "kh_kiehl01",
        x: 15,
        y: 182,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh4"
      },
      %{
        map: "kh_kiehl01",
        x: 35,
        y: 187,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh5"
      },
      %{
        map: "kh_kiehl01",
        x: 37,
        y: 187,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh6"
      },
      %{
        map: "kh_kiehl01",
        x: 39,
        y: 187,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh7"
      },
      %{
        map: "kh_kiehl01",
        x: 41,
        y: 187,
        dir: 0,
        sprite: 111,
        name: "Robots",
        scope: :shared,
        unique_name: "Robots#kh8"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
  end
end
