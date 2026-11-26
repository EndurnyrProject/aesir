defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.FlowerVase do
  @moduledoc """
  Offers a distraction during the temple infiltration.

  ## Behavior

  - Lets the player break the vase to draw away a guard.

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
        x: 115,
        y: 140,
        dir: 1,
        sprite: 111,
        name: "Flower Vase",
        scope: :shared,
        unique_name: "Flower Vase#vol"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :aru_vol, 0) > 2 and get_char_var(ctx, :aru_vol, 0) < 5 do
      {ctx, choice} =
        ctx
        |> describe_vase()
        |> next()
        |> select(["Destroy Vase", "Don't Destroy Vase"])

      if choice == 1 do
        ctx
        |> mes("^3355FFYou grasp the flower")
        |> mes("vase with both hands, and")
        |> mes("then hurl it to the ground.^000000")
        |> next()
        |> mes("^3355FF*Crash!*^000000")
        |> next()
        |> mes("[Guard Krodger]")
        |> mes("Who's there?!")
        |> disablenpc("Rachel Guard#vol2")
        |> enablenpc("Rachel Guard#vol2_1")
        |> donpcevent("vol_time2::OnEnable")
        |> set_char_var(:aru_vol, 4)
        |> disablenpc("Flower Vase#vol")
        |> close()
      else
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("A lot of loving care")
        |> mes("was put into arranging")
        |> mes("these flowers.. I can't")
        |> mes("bear to disturb their beauty.")
        |> next()
        |> mes("^3355FFAnd so you just")
        |> mes("stood there, looking")
        |> mes("a bit pitiable, but not")
        |> mes("really all that pathetic.^000000")
        |> close()
      end
    else
      ctx |> describe_vase() |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_vase(ctx) do
    ctx
    |> mes("^3355FFYou find a giant")
    |> mes("vase full of beautiful")
    |> mes("flowers that look freshly")
    |> mes("picked from a garden.^000000")
  end
end
