defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Chabimatan do
  @moduledoc """
  Chabimatan comments on her unwelcome admirer.

  ## Behavior

  - Her dialogue advances the domestic dispute quest and reveals its next scene at night.

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
    spawn: [
      %{map: "umbala", x: 145, y: 217, dir: 3, sprite: 783, name: "Chabimatan", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :event_umbala, 0) >= 3 ->
        ctx
        |> mes("[Chabimatan]")
        |> mes("...*Sigh* Umpokoriohtan seems")
        |> mes("to be married. I have no")
        |> mes("idea why he still flirts")
        |> mes("with other women. Maybe he's")
        |> mes("not very mature, or he's")
        |> mes("irresponsible...")
        |> next()
        |> mes("[Chabimatan]")
        |> mes("Well, whatever he is,")
        |> mes("he's certainly not")
        |> mes("romantic. Those pick-up")
        |> mes("lines of his could")
        |> mes("some work, maybe")
        |> mes("even some clean up.")
        |> close()

      get_char_var(ctx, :um_wind, 0) == 3 and gettime(ctx, 3) > 18 ->
        ctx
        |> set_char_var(:um_wind, 4)
        |> emotion(:fret)
        |> mes("[Chabimatan]")
        |> mes("Umbabah umbarbar woogawooga um")
        |> mes("Umbabah umbarbar woogawooga umbah")
        |> mes("Umumum! Wooga!")
        |> next()
        |> emotion(:o)
        |> mes("[Chabimatan]")
        |> mes("Umbabah~~~~~~~")
        |> mes("Woogawooga umbar umbar woo!")
        |> mes("Wooga umbar woogawoogagah.")
        |> enablenpc("Umpokoriohtan")
        |> enablenpc("#!@#$%")
        |> close()

      get_char_var(ctx, :um_wind, 0) == 3 ->
        ctx
        |> mes("[Chabimatan]")
        |> mes("Umbabah~~~~~~~")
        |> mes("Woogawooga umbar umbar woo")
        |> mes("woo woo! Nook nook~")
        |> mes("Wooga umbar wooga umbar")
        |> mes("wooga woogagah.")
        |> close()

      true ->
        ctx
        |> mes("[Chabimatan]")
        |> mes("Umbabah~~~~~~~")
        |> mes("Woogawooga umbar umbar")
        |> mes("woo woo woo nook nook.")
        |> mes("Wooga umbar wooga umbar")
        |> mes("wooga woogagah.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
