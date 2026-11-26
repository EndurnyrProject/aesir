defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Wainatan do
  @moduledoc """
  Wainatan complains about an unwelcome admirer.

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
    spawn: [%{map: "um_in", x: 101, y: 73, dir: 3, sprite: 783, name: "Wainatan", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :event_umbala, 0) >= 3 ->
        ctx
        |> mes("[Wainatan]")
        |> mes("I am sick and tired of this guy")
        |> mes("who always appears at night and bugs the hell out of me...")
        |> next()
        |> mes("[Wainatan]")
        |> mes("'Smooth operator that gets the")
        |> mes("job done?' Oh my god...!")
        |> mes("I hate him with a passion!")
        |> mes("I wish Umpokoriohtan would")
        |> mes("just drop dead.")
        |> close()

      get_char_var(ctx, :um_wind, 0) == 1 and gettime(ctx, 3) > 18 ->
        ctx
        |> set_char_var(:um_wind, 2)
        |> emotion(:fret)
        |> mes("[Wainatan]")
        |> mes("Umbaumbah umgagaga.")
        |> mes("Umbaumbawoogawoo gababah.")
        |> mes("Umbahumbabah gawoo.")
        |> next()
        |> emotion(:o)
        |> mes("[Wainatan]")
        |> mes("Wooga wooga woogagagah")
        |> mes("Wogagagah woogagagah")
        |> mes("Gawoo gawoo gah.")
        |> close()

      get_char_var(ctx, :um_wind, 0) == 1 ->
        ctx
        |> mes("[Wainatan]")
        |> mes("Umbabah! Umbaumbah wooga")
        |> mes("Woogawooga umbawooga umum.")
        |> mes("Umbabababababababababah.")
        |> close()

      true ->
        ctx
        |> mes("[Wainatan]")
        |> mes("Umbaumbah umbaumbah umbah")
        |> mes("Wooga wooga woogawooga wooga")
        |> mes("Umumumum umumumum umum.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
