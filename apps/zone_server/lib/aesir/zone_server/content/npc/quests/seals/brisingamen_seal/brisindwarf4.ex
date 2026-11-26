defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Brisindwarf4 do
  @moduledoc """
  Guards Grer's hiding place and tests visitors on the dwarfs' song.

  ## Behavior

  - Eligible visitors can recite the song to awaken Grer and advance the quest.
  - A timed challenge warns visitors and returns them to the dungeon on failure.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjo_dun02",
        x: 126,
        y: 36,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#brisindwarf4",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer1000", ctx) do
    ev_ontimer1000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer240000", ctx) do
    ev_ontimer240000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer298000", ctx) do
    ev_ontimer298000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer300000", ctx) do
    ev_ontimer300000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer301000", ctx) do
    ev_ontimer301000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      sealed?(ctx) ->
        ctx |> player_name() |> mes("Bah, no way out.") |> close()

      get_char_var(ctx, :god_brising, 0) > 45 and get_char_var(ctx, :god_brising, 0) < 50 ->
        ctx |> mes("[Grer]") |> mes("What!") |> hideoffnpc("Grer#1") |> close()

      get_char_var(ctx, :god_brising, 0) == 45 ->
        recite_song(ctx)

      true ->
        ctx
        |> mes("^3355FFYou found a hole filled with some clod and a lump of coal.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    cond do
      sealed?(ctx) ->
        ctx |> player_name() |> mes("Beh, no way out.") |> close()

      get_char_var(ctx, :god_brising, 0) == 44 ->
        challenge_visitor(ctx)

      get_char_var(ctx, :god_brising, 0) == 45 ->
        ctx
        |> mes("[Male Voice]")
        |> mes("Prove it!")
        |> mes("Otherwise, leave me alone and let me mine silver. Silver...! Heh heh heh...")
        |> stopnpctimer()
        |> startnpctimer()
        |> close()

      true ->
        warp(ctx, "mjo_dun02", 118, 56)
    end
  end

  def ev_ontimer1000(ctx) do
    mapannounce(ctx, "mjo_dun02", "Grer: Hurry and show that I can trust you!", 0, 7_396_315)
  end

  def ev_ontimer240000(ctx) do
    mapannounce(ctx, "mjo_dun02", "Grer: Grrr, I won't wait much longer!", 0, 7_396_315)
  end

  def ev_ontimer298000(ctx) do
    mapannounce(ctx, "mjo_dun02", "Grer: Farewell, human!", 0, 7_396_315)
  end

  def ev_ontimer300000(ctx) do
    ctx |> warp("mjo_dun02", 118, 56) |> hideonnpc("Grer#1")
  end

  def ev_ontimer301000(ctx), do: stopnpctimer(ctx)

  defp sealed?(ctx) do
    get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) or
      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0)
  end

  defp player_name(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp challenge_visitor(ctx) do
    {ctx, choice} =
      ctx
      |> emotion(:surprise, playerattached(ctx))
      |> mes("[Male Voice]")
      |> mes("Don't come any closer!")
      |> mes("How the hell do I feel")
      |> mes("Freya's presense on you?")
      |> mes("Tell me who you are!")
      |> next()
      |> select(["I am sent by Berling.", "Wah, you freaked me out!"])

    case choice do
      1 ->
        ctx
        |> mes("[Male Voice]")
        |> mes("Lies! Lies!")
        |> mes("Prove it!")
        |> mes("Prove yourself!")
        |> set_char_var(:god_brising, 45)
        |> initnpctimer()
        |> close()

      2 ->
        ctx |> mes("[Male Voice]") |> mes("Get out of here!") |> close()

      _ ->
        ctx
    end
  end

  defp recite_song(ctx) do
    ctx =
      ctx
      |> player_name()
      |> mes("Let's see.")
      |> mes("Um, that song.")
      |> mes("What was the first line...?")
      |> next()
      |> song_line(:"dwarfsong1$", "No jewel in the world can compare.")
      |> song_prompt(:"dwarfsong1$", ["Then...ummm..", "The second line?"])
      |> song_line(:"dwarfsong2$", "Our masterpiece made from love.")
      |> song_prompt(:"dwarfsong2$", ["Now, what was", "the third line...?"])
      |> song_line(:"dwarfsong3$", "She wanted the dazzling necklace.")
      |> song_prompt(:"dwarfsong3$", ["Now, the fourth", "line after that..."])
      |> song_line(:"dwarfsong4$", "We wanted the goddess of beauty.")
      |> song_prompt(:"dwarfsong4$", ["Alright, now", "for the last line..."])
      |> song_line(:"dwarfsong5$", "Our happiest times were with her.")
      |> song_prompt(:"dwarfsong5$", ["Alright, let's give it a try."])
      |> player_name()

    ctx =
      Enum.reduce(
        [:"dwarfsong1$", :"dwarfsong2$", :"dwarfsong3$", :"dwarfsong4$", :"dwarfsong5$"],
        ctx,
        fn key, acc ->
          mes(acc, Rathena.concat(Rathena.concat("", get_temp_var(acc, key, "")), ""))
        end
      )

    ctx = next(ctx)

    if get_temp_var(ctx, :point, 0) > 4 do
      ctx
      |> hideoffnpc("Grer#1")
      |> mes("[Grer]")
      |> mes("Wha--?")
      |> mes("Berling")
      |> mes("did send you!")
      |> set_char_var(:god_brising, 46)
      |> stopnpctimer()
      |> close()
    else
      ctx
      |> mes("[Grer]")
      |> mes("Bah!")
      |> mes("I knew it!")
      |> mes("I can't trust you!")
      |> close2()
      |> warp("mjo_dun02", 118, 56)
    end
  end

  defp song_line(ctx, key, expected) do
    {ctx, line} = input(ctx, :string)
    ctx = set_temp_var(ctx, key, line)

    if get_temp_var(ctx, key, "") == expected do
      set_temp_var(ctx, :point, get_temp_var(ctx, :point, 0) + 1)
    else
      ctx
    end
  end

  defp song_prompt(ctx, key, lines) do
    ctx = player_name(ctx)
    ctx = mes(ctx, Rathena.concat(Rathena.concat(" ", get_temp_var(ctx, key, "")), ""))
    ctx = Enum.reduce(lines, ctx, fn line, acc -> mes(acc, line) end)
    next(ctx)
  end
end
