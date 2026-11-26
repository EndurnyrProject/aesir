defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.HotLandSurface16537 do
  @moduledoc """
  Records the second volcano surface temperature.

  ## Behavior

  - Requires the pyrometer and report form to advance the investigation.

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
        map: "thor_v02",
        x: 165,
        y: 37,
        dir: 3,
        sprite: 111,
        name: "Hot Land Surface",
        scope: :shared,
        unique_name: "Hot Land Surface#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_vol, 0) == 9 and count_item(ctx, 7704) > 0 and
          count_item(ctx, 7342) > 0 ->
        ctx
        |> mes("^3355FFYou use the pyrometer")
        |> mes("to check the surface")
        |> mes("temperature of the ground")
        |> mes("here in the volcano.^000000")
        |> next()
        |> mes("^3131FFBeep-- Beep-- Bee-^000000")
        |> next()
        |> mes("^3131FFCurrent Temperature: 2270 ThT^000000")
        |> next()
        |> mes("^3355FFYou record the")
        |> mes("temperature in")
        |> mes("your report.^000000")
        |> changequest(2118, 2119)
        |> set_char_var(:aru_vol, 10)
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 9 ->
        ctx
        |> mes("^3355FFYou need both the")
        |> mes("pyrometer and the")
        |> mes("report form to measure")
        |> mes("and record the temperature")
        |> mes("of the ground's surface here.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFThis patch of ground")
        |> mes("emits an intense heat")
        |> mes("that stings your face.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
