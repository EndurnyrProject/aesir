defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Soldier107233 do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 107,
        y: 233,
        dir: 5,
        sprite: 454,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ep13_3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Anxious Soldier]")
      |> mes(
        "Hurry, I am in big trouble. I lost all the Manuk Coins. I think I dropped them somewhere on the snowfield. Gosh, I saw them right before I fell asleep!"
      )
      |> close()
    else
      ctx |> mes("[Anxious Soldier]") |> mes("Qosi dhhui rffd poaner ouh.") |> close()
    end
  end
end
