defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.FemaleCustomer do
  @moduledoc """
  A customer talks to the bartender about her loneliness.

  ## Behavior

  - The conversation changes depending on the adventurer’s sex.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 237,
        y: 131,
        dir: 1,
        sprite: 940,
        name: "Female Customer",
        scope: :shared,
        unique_name: "Female Customer#ve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Female Customer]")
      |> mes("Bartender, aren't any of")
      |> mes("your regulars nice young")
      |> mes("men? You know, I've been")
      |> mes("pretty lonely lately...")
      |> next()

    if sex(ctx) == 0 do
      ctx
      |> mes("[Bartender]")
      |> mes("Haha, well,")
      |> mes("I'm not so sure..")
      |> next()
      |> mes("[Bartender]")
      |> mes("How about... me?")
      |> next()
      |> mes("[Female Customer]")
      |> mes("Hmpf...")
      |> next()
      |> mes("[Bartender]")
      |> mes("Oh, come on!")
      |> mes("I was kidding~")
      |> emotion(:cry)
      |> close()
    else
      ctx =
        ctx
        |> mes("[Bartender]")
        |> mes("Haha, well,")
        |> mes("I'm not so sure..")
        |> mes("What about this nice")
        |> mes("young adventurer here?")
        |> next()

      ctx =
        ctx |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]")) |> mes("Meee?")

      ctx =
        ctx
        |> emotion(:profusely_sweat, playerattached(ctx))
        |> next()
        |> mes("[Female Customer]")
        |> mes("Mmm...")
        |> mes("Not my style.")

      ctx |> emotion(:think, playerattached(ctx)) |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
