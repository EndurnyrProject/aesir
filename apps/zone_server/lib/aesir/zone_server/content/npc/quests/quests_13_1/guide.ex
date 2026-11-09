defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Guide do
  @moduledoc """
  Lighthalzen's guide, who welcomes arrivals and points a registered adventurer at the
  Rekenber registration office.

  ## Behavior

  - Welcomes the player to Lighthalzen.
  - Past step 8 also explains that registrations happen on the Rekenber second floor and warns
    the player not to get lost.

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
        map: "lighthalzen",
        x: 220,
        y: 292,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#ep13_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Guide]")
      |> mes("Welcome! You've arrived at Lighthalzen, which is the base of three kingdoms.")

    if get_char_var(ctx, :ep13_ryu, 0) > 8 do
      registration_directions(ctx)
    else
      close(ctx)
    end
  end

  defp registration_directions(ctx) do
    ctx
    |> next()
    |> mes("[Guide]")
    |> mes(
      "You have to register your name. Go to the 2nd floor in Rekenbereu on the northwest side."
    )
    |> next()
    |> mes("[Guide]")
    |> mes("Be careful not to lose your way!")
    |> close()
  end
end
