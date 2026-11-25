defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz09 do
  @moduledoc """
  A cursed spirit draws the player into a memory.

  ## Behavior

  - Transfers the player into a memory at the appropriate stage.

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
  - Replaced the impossible `(lhz_curse > 0 && lhz_curse < 12) && (lhz_curse > 12 && lhz_curse < 26)` with the alternative ranges.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 206,
        y: 129,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz09",
        trigger: {5, 5}
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

  defp encounter(ctx, curse) do
    cond do
      curse == 12 ->
        ctx
        |> mes("............")
        |> next()
        |> mes("............")
        |> soundeffect("loli_ruri_stand.wav", 0)
        |> sc_start(:sc_curse, 1000, 0)
        |> close2()
        |> warp("lhz_que01", 26, 27)

      curse > 0 and curse < 26 ->
        sc_start(ctx, :sc_curse, 1000, 0)

      true ->
        ctx
    end
  end
end
