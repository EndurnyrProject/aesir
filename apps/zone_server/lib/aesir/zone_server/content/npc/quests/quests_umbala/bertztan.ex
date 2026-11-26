defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Bertztan do
  @moduledoc """
  Bertztan shares her feelings about an unwelcome admirer.

  ## Behavior

  - Her dialogue advances the domestic dispute quest at night.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "um_in", x: 94, y: 123, dir: 5, sprite: 783, name: "Bertztan", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :event_umbala, 0) >= 3 ->
        ctx
        |> mes("[Bertztan]")
        |> mes("...*Sigh* That sicko")
        |> mes("Umpo-whatever! I told him")
        |> mes("I don't like him, but he")
        |> mes("just doesn't listen!")
        |> mes("I wish...I wish he would")
        |> mes("just disappear!")
        |> close()

      get_char_var(ctx, :um_wind, 0) == 2 and gettime(ctx, 3) > 18 ->
        ctx
        |> set_char_var(:um_wind, 3)
        |> emotion(:fret)
        |> mes("[Bertztan]")
        |> mes("Umbaumbah umgagaga.")
        |> mes("Umbaumbawoogawoo gababah.")
        |> mes("Umbahumbabah gawoo.")
        |> next()
        |> emotion(:o)
        |> mes("[Bertztan]")
        |> mes("Wooga umbar umbar umbah!")
        |> mes("Umbar woogagaga woo! Woo! Woo!")
        |> mes("Wooga~ wooga~ Woo woo woo umbar.")
        |> close()

      get_char_var(ctx, :um_wind, 0) == 2 ->
        ctx
        |> mes("[Bertztan]")
        |> mes("Umbar woogaumbarumbah um!")
        |> mes("Um~ wooga wooga umbarum.")
        |> mes("Umbah...wooum.")
        |> close()

      true ->
        ctx
        |> mes("[Bertztan]")
        |> mes("Umbar wooga umbar umbah um!")
        |> mes("Um~ woogawooga umbar um.")
        |> mes("Umbah...wooum.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
