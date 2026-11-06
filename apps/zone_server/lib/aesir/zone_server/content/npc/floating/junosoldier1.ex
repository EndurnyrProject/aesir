defmodule Aesir.ZoneServer.Content.Npc.Floating.Junosoldier1 do
  @moduledoc """
  Juno soldier who warns travelers about the Lava Golem near the city.

  ## Behavior

  - Describes how the monster's molten body melts steel armor and weapons.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf
    - massdriller
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/yuno.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 150,
        y: 283,
        dir: 4,
        sprite: 852,
        name: "Juno Soldier",
        scope: :renewal,
        unique_name: "Juno Soldier#juno"
      },
      %{
        map: "yuno",
        x: 150,
        y: 283,
        dir: 4,
        sprite: 105,
        name: "Juno Soldier",
        scope: :pre_renewal,
        unique_name: "Juno Soldier#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Juno Soldier]")
    |> mes("Welcome to Juno, the city of noble-mindedness.")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "There is a monster near here known as Lava Golem. This golem is made from a stone heart whose power happened to be amplified with magic power when it was swept away by molten rock."
    )
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "The lava dripping from its body is so hot that it can melt down armor and weapons made out of high quality steel."
    )
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "You'd better be careful when you encounter this monster. It will damage armor and weapons in the twinkling of an eye."
    )
    |> close()
  end
end
