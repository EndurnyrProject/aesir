defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.PromotionalStaff do
  @moduledoc """
  Prontera's promotional staff, who pitches the expedition beyond the time-space gap to
  passers-by.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 163,
        y: 53,
        dir: 3,
        sprite: 100,
        name: "Promotional Staff",
        scope: :shared,
        unique_name: "Promotional Staff#prt"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.PromotionalStaff
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = PromotionalStaff.call(ctx, [])
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
