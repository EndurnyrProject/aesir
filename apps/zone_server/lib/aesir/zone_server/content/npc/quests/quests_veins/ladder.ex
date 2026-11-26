defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Ladder do
  @moduledoc """
  A ladder offers a way out of the guarded temple.

  ## Behavior

  - During the infiltration, the player can climb it to escape.

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
        map: "ra_temin",
        x: 73,
        y: 126,
        dir: 1,
        sprite: 111,
        name: "Ladder",
        scope: :shared,
        unique_name: "Ladder#vol1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :aru_vol, 0) == 5 do
      {ctx, choice} =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wait, I can use this")
        |> mes("ladder to sneak out of")
        |> mes("here! I snuck inside so")
        |> mes("I'd get caught if I just")
        |> mes("passed the guards...")
        |> next()
        |> select(["Climb Ladder", "Cancel"])

      if choice == 1 do
        ctx
        |> mes("^3355FFYou climbed the")
        |> mes("ladder over the")
        |> mes("wall and snuck out.^000000")
        |> close2()
        |> warp("ra_temin", 74, 136)
      else
        ctx
        |> mes("^3355FFYou decided not to climb")
        |> mes("up the ladder for now.^000000")
        |> close()
      end
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
