defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz10 do
  @moduledoc """
  A cursed spirit draws the player to a worker’s memory.

  ## Behavior

  - Checks inventory capacity and transfers the player into a memory.

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
  - Replaced the impossible `(lhz_curse > 0 && lhz_curse < 16) && (lhz_curse > 16 && lhz_curse < 26)` with the alternative ranges.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 282,
        y: 166,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz10",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 do
      encounter(ctx, get_char_var(ctx, :lhz_curse, 0))
    else
      ctx
    end
  end

  defp encounter(ctx, 16) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("^3355FFThere's something on")
      |> mes("the floor, but you can't")
      |> mes("really take a good look at")
      |> mes("what it is right now. Perhaps")
      |> mes("if you freed up more space")
      |> mes("in your inventory...")
      |> close()
    else
      ctx
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> soundeffect("loli_ruri_stand.wav", 0)
      |> sc_start(:sc_curse, 1000, 0)
      |> close2()
      |> warp("lhz_que01", 98, 59)
    end
  end

  defp encounter(ctx, curse) when curse > 0 and curse < 26,
    do: sc_start(ctx, :sc_curse, 1000, 0)

  defp encounter(ctx, _curse), do: ctx
end
