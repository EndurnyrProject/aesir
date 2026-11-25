defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz021 do
  @moduledoc """
  A restless spirit curses visitors carrying its token.

  ## Behavior

  - Starts the curse quest or troubles the player with a spirit’s voice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_dun02",
        x: 244,
        y: 229,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz02-1",
        trigger: {3, 3}
      },
      %{
        map: "lhz_dun02",
        x: 60,
        y: 293,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz02-2",
        trigger: {3, 3}
      },
      %{
        map: "lhz_dun02",
        x: 267,
        y: 278,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz02-3",
        trigger: {3, 3}
      },
      %{
        map: "lhz_dun02",
        x: 94,
        y: 199,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz02-4",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 do
      encounter_spirit(ctx, get_char_var(ctx, :lhz_curse, 0))
    else
      ctx
    end
  end

  defp encounter_spirit(ctx, 0) do
    ctx
    |> soundeffect("tao_gunka_stand.wav", 0)
    |> set_char_var(:lhz_curse, 1)
    |> setquest(2086)
  end

  defp encounter_spirit(ctx, curse) when curse < 26 do
    ctx =
      ctx
      |> set_temp_var(:lhz_ghost, Enum.random(1..10))
      |> sc_start(:sc_curse, 1000, 0)
      |> soundeffect("tao_gunka_stand.wav", 0)

    case get_temp_var(ctx, :lhz_ghost, 0) do
      1 -> spirit_speaks(ctx, ["...elp....help..."])
      4 -> spirit_speaks(ctx, ["I...", "I despise the living."])
      _ -> ctx
    end
  end

  defp encounter_spirit(ctx, _curse), do: ctx

  defp spirit_speaks(ctx, lines) do
    ctx =
      ctx
      |> mes("[??????]")
      |> mes("...................")
      |> next()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> mes("[??????]")

    ctx = Enum.reduce(lines, ctx, fn line, acc -> mes(acc, line) end)
    close(ctx)
  end
end
